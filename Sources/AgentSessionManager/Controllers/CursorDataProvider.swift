import Foundation

/// Provides status line data for Cursor CLI panes by combining two data sources:
///   1. A Cursor hooks file (`afterAgentResponse`) that pipes model info to a per-pane temp file
///   2. Periodic git/duration/version polling (same as `ToolAgnosticDataProvider`)
///
/// The hooks-based model detection requires a user-level `~/.cursor/hooks.json` with an
/// `afterAgentResponse` hook that writes stdin to a file keyed by the `AGENT_SESSION_MANAGER_PANE_ID`
/// environment variable. `CursorHookSetup` handles creating/updating this file.
@MainActor
final class CursorDataProvider: StatusLineDataProvider {
    var onUpdate: ((StatusLineData) -> Void)?
    var onAttention: ((PaneAttentionEvent) -> Void)?

    let workingDirectory: String
    let processStartTime: Date
    let paneID: UUID
    let paneName: String
    let tabID: UUID
    let tabName: String
    let hookOutputFilePath: String
    let attentionFilePath: String
    let lifecycleFilePath: String

    private var refreshTimer: Timer?
    private var versionFetchedVersion: String?
    private var hookSource: DispatchSourceFileSystemObject?
    private var attentionSource: DispatchSourceFileSystemObject?
    private var lifecycleSource: DispatchSourceFileSystemObject?
    private var lastHookModel: StatusLineData.Model?
    private let attentionDebounceLock = NSLock()
    private var attentionDebounceWork: DispatchWorkItem?
    private var lastAttentionPayloadFingerprint: Int?
    var onActivityChanged: ((Bool) -> Void)?

    init(
        workingDirectory: String, paneID: UUID, processStartTime: Date,
        paneName: String = "", tabID: UUID = UUID(), tabName: String = ""
    ) {
        self.workingDirectory = workingDirectory
        self.paneID = paneID
        self.processStartTime = processStartTime
        self.paneName = paneName
        self.tabID = tabID
        self.tabName = tabName
        self.hookOutputFilePath =
            NSTemporaryDirectory() + "agent-session-manager-cursor-hook-\(paneID.uuidString).json"
        self.attentionFilePath =
            NSTemporaryDirectory() + "agent-session-manager-cursor-attention-\(paneID.uuidString).json"
        self.lifecycleFilePath =
            NSTemporaryDirectory() + "agent-session-manager-cursor-lifecycle-\(paneID.uuidString).json"
    }

    func start() {
        do {
            try FileManager.default.createDirectory(
                at: CursorHookSetup.hooksDirectory, withIntermediateDirectories: true)
            try CursorHookSetup.writeScript(
                at: CursorHookSetup.hookScriptPath, content: CursorHookSetup.hookScriptContent)
            try CursorHookSetup.writeScript(
                at: CursorHookSetup.stopHookScriptPath, content: CursorHookSetup.stopHookScriptContent)
            try CursorHookSetup.writeScript(
                at: CursorHookSetup.lifecycleHookScriptPath,
                content: CursorHookSetup.lifecycleHookScriptContent)
            let configPath = CursorHookSetup.hooksConfigPath
            var config: [String: Any] = ["version": 1, "hooks": [String: Any]()]
            if let existingData = try? Data(contentsOf: configPath),
                let existing = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]
            {
                config = existing
            }
            var hooks = config["hooks"] as? [String: Any] ?? [:]
            var needsWrite = false
            needsWrite =
                CursorHookSetup.installHookEntry(
                    into: &hooks,
                    eventName: "beforeSubmitPrompt",
                    entry: CursorHookSetup.lifecycleHookEntry,
                    scriptName: CursorHookSetup.lifecycleHookScriptName
                ) || needsWrite
            needsWrite =
                CursorHookSetup.installHookEntry(
                    into: &hooks,
                    eventName: "afterAgentResponse",
                    entry: CursorHookSetup.hookEntry,
                    scriptName: CursorHookSetup.hookScriptName
                ) || needsWrite
            needsWrite =
                CursorHookSetup.installHookEntry(
                    into: &hooks,
                    eventName: "stop",
                    entry: CursorHookSetup.stopHookEntry,
                    scriptName: CursorHookSetup.stopHookScriptName
                ) || needsWrite
            if needsWrite {
                config["hooks"] = hooks
                if config["version"] == nil { config["version"] = 1 }
                let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: configPath, options: .atomic)
            }
        } catch {
            TracingService.shared.record(
                "statusline.cursor.hook_setup_failed",
                attributes: cursorTraceAttributes(["error": error.localizedDescription]))
        }
        FileManager.default.createFile(atPath: hookOutputFilePath, contents: nil)
        let hookFD = open(hookOutputFilePath, O_EVTONLY)
        if hookFD >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: hookFD,
                eventMask: [.write, .extend],
                queue: .global(qos: .utility)
            )
            source.setEventHandler { [weak self] in
                guard let self,
                    let data = try? Data(contentsOf: URL(filePath: self.hookOutputFilePath)),
                    !data.isEmpty,
                    let parsed = CursorHookPayload.parse(data)
                else { return }
                let model = StatusLineData.Model(id: parsed.model, displayName: parsed.model)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.lastHookModel = model
                    self.refreshNow()
                }
            }
            source.setCancelHandler { close(hookFD) }
            source.resume()
            hookSource = source
        }
        FileManager.default.createFile(atPath: lifecycleFilePath, contents: nil)
        startLifecycleWatcher()
        configureAttentionWatcher(
            enabled: SettingsPersistence.load(NotificationConfig.self, from: "notification-settings.json")?
                .isCursorHookAttentionEnabled ?? true
        )
        Task { [weak self] in
            guard let self else { return }
            let version = await self.runShell(
                "PATH=/opt/homebrew/bin:/usr/local/bin:$PATH agent --version 2>/dev/null | head -1")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run { [weak self] in
                self?.versionFetchedVersion = version
            }
        }
        refreshNow()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshNow()
            }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        hookSource?.cancel()
        hookSource = nil
        lifecycleSource?.cancel()
        lifecycleSource = nil
        attentionDebounceLock.lock()
        attentionDebounceWork?.cancel()
        attentionDebounceWork = nil
        attentionDebounceLock.unlock()
        attentionSource?.cancel()
        attentionSource = nil
        lastAttentionPayloadFingerprint = nil
        try? FileManager.default.removeItem(atPath: hookOutputFilePath)
        try? FileManager.default.removeItem(atPath: attentionFilePath)
        try? FileManager.default.removeItem(atPath: lifecycleFilePath)
    }

    func configureAttentionWatcher(enabled: Bool) {
        attentionDebounceLock.lock()
        attentionDebounceWork?.cancel()
        attentionDebounceWork = nil
        attentionDebounceLock.unlock()
        attentionSource?.cancel()
        attentionSource = nil
        lastAttentionPayloadFingerprint = nil
        guard enabled else { return }

        FileManager.default.createFile(atPath: attentionFilePath, contents: nil)
        let attentionFD = open(attentionFilePath, O_EVTONLY)
        guard attentionFD >= 0 else {
            TracingService.shared.record(
                "statusline.cursor.attention_watcher.failed",
                attributes: cursorTraceAttributes(["reason": "open_failed"]))
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: attentionFD,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.attentionDebounceLock.lock()
            self.attentionDebounceWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self,
                    let data = try? Data(contentsOf: URL(filePath: self.attentionFilePath)),
                    !data.isEmpty
                else { return }
                var hasher = Hasher()
                hasher.combine(data)
                let fingerprint = hasher.finalize()
                Task { @MainActor in
                    guard fingerprint != self.lastAttentionPayloadFingerprint else { return }
                    self.lastAttentionPayloadFingerprint = fingerprint
                    TracingService.shared.record(
                        "statusline.cursor.attention.received",
                        attributes: self.cursorTraceAttributes([:]))
                    self.onAttention?(.cursorStop)
                }
            }
            self.attentionDebounceWork = work
            self.attentionDebounceLock.unlock()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
        source.setCancelHandler { close(attentionFD) }
        source.resume()
        attentionSource = source
        TracingService.shared.record(
            "statusline.cursor.attention_watcher.started",
            attributes: cursorTraceAttributes([:]))
    }

    var currentDurationMs: Double {
        max(0, Date().timeIntervalSince(processStartTime)) * 1000
    }

    private func startLifecycleWatcher() {
        let lifecycleFD = open(lifecycleFilePath, O_EVTONLY)
        guard lifecycleFD >= 0 else {
            TracingService.shared.record(
                "statusline.cursor.lifecycle_watcher.failed",
                attributes: cursorTraceAttributes(["reason": "open_failed"]))
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: lifecycleFD,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self,
                let data = try? Data(contentsOf: URL(filePath: self.lifecycleFilePath)),
                let payload = CursorLifecyclePayload.parse(data)
            else { return }
            Task { @MainActor in
                let isWorking = payload.hookEventName == "beforeSubmitPrompt"
                TracingService.shared.record(
                    "statusline.cursor.lifecycle.received",
                    attributes: self.cursorTraceAttributes([
                        "hook_event": payload.hookEventName,
                        "state": isWorking ? "working" : "stopped",
                    ]))
                self.onActivityChanged?(isWorking)
            }
        }
        source.setCancelHandler { close(lifecycleFD) }
        source.resume()
        lifecycleSource = source
        TracingService.shared.record(
            "statusline.cursor.lifecycle_watcher.started",
            attributes: cursorTraceAttributes([:]))
    }

    private func cursorTraceAttributes(_ additional: [String: String]) -> [String: String] {
        [
            "pane.id": paneID.uuidString,
            "pane.name": paneName,
            "tab.id": tabID.uuidString,
            "tab.name": tabName,
        ].merging(additional) { _, new in new }
    }

    // MARK: - Periodic Refresh

    private func refreshNow() {
        Task { [weak self] in
            guard let self else { return }
            let branch = await self.runShell("git branch --show-current 2>/dev/null")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let wd = self.workingDirectory
            let gitStats = await GitDiffStats.compute(in: wd)

            let data = StatusLineData(
                model: self.lastHookModel,
                cost: StatusLineData.Cost(
                    totalCostUsd: nil,
                    totalDurationMs: self.currentDurationMs,
                    totalLinesAdded: gitStats?.added,
                    totalLinesRemoved: gitStats?.removed
                ),
                contextWindow: nil,
                rateLimits: nil,
                worktree: StatusLineData.Worktree(
                    name: URL(filePath: wd).lastPathComponent,
                    branch: branch
                ),
                workspace: StatusLineData.Workspace(
                    gitWorktree: wd
                ),
                effort: nil,
                thinking: nil,
                agent: nil,
                outputStyle: nil,
                vim: nil,
                sessionName: nil,
                version: self.versionFetchedVersion,
                exceeds200kTokens: nil,
                pr: nil,
                sessionStatus: nil
            )

            await MainActor.run { [weak self] in
                self?.onUpdate?(data)
            }
        }
    }

    // MARK: - Shell Helper

    private func runShell(_ command: String) async -> String? {
        await withCheckedContinuation { continuation in
            let task = Process()
            let outPipe = Pipe()
            task.executableURL = URL(filePath: "/bin/zsh")
            task.arguments = ["-c", command]
            task.currentDirectoryURL = URL(filePath: workingDirectory)
            task.standardOutput = outPipe
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { process in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0, !data.isEmpty {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - Hook Payload

/// Minimal representation of the JSON that Cursor pipes to hook scripts via stdin.
/// We only need the `model` field; the rest is ignored via `AdditionalKeysDecodable` pattern.
struct CursorHookPayload {
    let model: String

    static func parse(_ data: Data) -> CursorHookPayload? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let model = dict["model"] as? String,
            !model.isEmpty
        else { return nil }
        return CursorHookPayload(model: model)
    }
}

struct CursorLifecyclePayload {
    let hookEventName: String

    static func parse(_ data: Data) -> CursorLifecyclePayload? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hookEventName = dict["hook_event_name"] as? String,
            !hookEventName.isEmpty
        else { return nil }
        return CursorLifecyclePayload(hookEventName: hookEventName)
    }
}

// MARK: - Hook Setup

/// Manages the user-level `~/.cursor/hooks.json` to include an `afterAgentResponse` hook
/// (for model detection) and a `stop` hook (for notifications) that write their payloads
/// to per-pane temp files identified by the `AGENT_SESSION_MANAGER_PANE_ID` environment variable.
enum CursorHookSetup {
    fileprivate static let hookScriptName = "agent-session-manager-cursor-hook.sh"
    fileprivate static let stopHookScriptName = "agent-session-manager-cursor-stop-hook.sh"
    fileprivate static let lifecycleHookScriptName = "agent-session-manager-cursor-lifecycle-hook.sh"

    static var hooksDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".cursor/hooks")
    }

    static var hookScriptPath: URL {
        hooksDirectory.appending(path: hookScriptName)
    }

    static var stopHookScriptPath: URL {
        hooksDirectory.appending(path: stopHookScriptName)
    }

    static var lifecycleHookScriptPath: URL {
        hooksDirectory.appending(path: lifecycleHookScriptName)
    }

    static var hooksConfigPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".cursor/hooks.json")
    }

    /// The hook script reads stdin (the JSON payload from Cursor) and writes it to a
    /// temp file keyed by the AGENT_SESSION_MANAGER_PANE_ID env var.
    static let hookScriptContent = """
        #!/bin/bash
        if [ -n "$AGENT_SESSION_MANAGER_PANE_ID" ]; then
          cat > "/tmp/agent-session-manager-cursor-hook-${AGENT_SESSION_MANAGER_PANE_ID}.json"
        else
          cat > /dev/null
        fi
        exit 0

        """

    /// The stop hook writes its payload to the per-pane attention file, triggering a notification.
    static let stopHookScriptContent = """
        #!/bin/bash
        if [ -n "$AGENT_SESSION_MANAGER_PANE_ID" ]; then
          payload="$(cat)"
          printf '%s' "$payload" > "/tmp/agent-session-manager-cursor-attention-${AGENT_SESSION_MANAGER_PANE_ID}.json"
          printf '%s' "$payload" > "/tmp/agent-session-manager-cursor-lifecycle-${AGENT_SESSION_MANAGER_PANE_ID}.json"
        else
          cat > /dev/null
        fi
        exit 0

        """

    static let lifecycleHookScriptContent = """
        #!/bin/bash
        if [ -n "$AGENT_SESSION_MANAGER_PANE_ID" ]; then
          cat > "/tmp/agent-session-manager-cursor-lifecycle-${AGENT_SESSION_MANAGER_PANE_ID}.json"
        else
          cat > /dev/null
        fi
        exit 0

        """

    static let hookEntry: [String: Any] = [
        "command": "./hooks/\(hookScriptName)"
    ]

    static let stopHookEntry: [String: Any] = [
        "command": "./hooks/\(stopHookScriptName)"
    ]

    static let lifecycleHookEntry: [String: Any] = [
        "command": "./hooks/\(lifecycleHookScriptName)"
    ]

    fileprivate static func writeScript(at path: URL, content: String) throws {
        let currentContent = try? String(contentsOf: path, encoding: .utf8)
        if currentContent == content { return }
        try content.write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: path.path)
    }

    /// Returns `true` if the entry was added (config needs writing).
    @discardableResult
    fileprivate static func installHookEntry(
        into hooks: inout [String: Any],
        eventName: String,
        entry: [String: Any],
        scriptName: String
    ) -> Bool {
        var entries = hooks[eventName] as? [[String: Any]] ?? []
        let alreadyInstalled = entries.contains {
            ($0["command"] as? String)?.contains(scriptName) == true
        }
        guard !alreadyInstalled else { return false }
        entries.append(entry)
        hooks[eventName] = entries
        return true
    }
}
