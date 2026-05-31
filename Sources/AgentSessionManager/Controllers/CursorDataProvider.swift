import Foundation

/// Provides status line data for Cursor CLI panes by combining two data sources:
///   1. A Cursor hooks file (`afterAgentResponse`) that pipes model info to a per-pane temp file
///   2. Periodic git/duration/version polling (same as `ToolAgnosticDataProvider`)
///
/// The hooks-based model detection requires a user-level `~/.cursor/hooks.json` with an
/// `afterAgentResponse` hook that writes stdin to a file keyed by the `AGENT_SESSION_MANAGER_PANE_ID`
/// environment variable. `CursorHookSetup` handles creating/updating this file.
final class CursorDataProvider: StatusLineDataProvider {
    var onUpdate: ((StatusLineData) -> Void)?
    var onAttention: ((PaneAttentionEvent) -> Void)?

    let workingDirectory: String
    let processStartTime: Date
    let paneID: UUID
    let hookOutputFilePath: String
    let attentionFilePath: String

    private var refreshTimer: Timer?
    private var versionFetchedVersion: String?
    private var hookSource: DispatchSourceFileSystemObject?
    private var attentionSource: DispatchSourceFileSystemObject?
    private var lastHookModel: StatusLineData.Model?
    private let attentionDebounceLock = NSLock()
    private var attentionDebounceWork: DispatchWorkItem?
    private var lastAttentionPayloadFingerprint: Int?

    init(workingDirectory: String, paneID: UUID, processStartTime: Date) {
        self.workingDirectory = workingDirectory
        self.paneID = paneID
        self.processStartTime = processStartTime
        self.hookOutputFilePath =
            NSTemporaryDirectory() + "agent-session-manager-cursor-hook-\(paneID.uuidString).json"
        self.attentionFilePath =
            NSTemporaryDirectory() + "agent-session-manager-cursor-attention-\(paneID.uuidString).json"
    }

    func start() {
        CursorHookSetup.ensureHooksConfigured()
        startHookFileWatcher()
        startAttentionFileWatcher()
        fetchVersion()
        refreshNow()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refreshNow()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        hookSource?.cancel()
        hookSource = nil
        stopAttentionWatcher()
        try? FileManager.default.removeItem(atPath: hookOutputFilePath)
        try? FileManager.default.removeItem(atPath: attentionFilePath)
    }

    var currentDurationMs: Double {
        max(0, Date().timeIntervalSince(processStartTime)) * 1000
    }

    // MARK: - Hook File Watching

    private func startHookFileWatcher() {
        FileManager.default.createFile(atPath: hookOutputFilePath, contents: nil)
        let fd = open(hookOutputFilePath, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        src.setEventHandler { [weak self] in
            self?.handleHookFileUpdate()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        hookSource = src
    }

    private func handleHookFileUpdate() {
        guard let data = try? Data(contentsOf: URL(filePath: hookOutputFilePath)),
            !data.isEmpty
        else { return }

        guard let parsed = CursorHookPayload.parse(data) else { return }

        let model = StatusLineData.Model(id: parsed.model, displayName: parsed.model)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.lastHookModel = model
            self.refreshNow()
        }
    }

    // MARK: - Attention File Watching

    private func startAttentionFileWatcher() {
        guard SettingsPersistence.isCursorHookAttentionEnabled() else { return }
        FileManager.default.createFile(atPath: attentionFilePath, contents: nil)
        let fd = open(attentionFilePath, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        src.setEventHandler { [weak self] in
            self?.scheduleAttentionSignalProcessing()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        attentionSource = src
    }

    private func stopAttentionWatcher() {
        attentionDebounceLock.lock()
        attentionDebounceWork?.cancel()
        attentionDebounceWork = nil
        attentionDebounceLock.unlock()
        attentionSource?.cancel()
        attentionSource = nil
        lastAttentionPayloadFingerprint = nil
    }

    private func scheduleAttentionSignalProcessing() {
        attentionDebounceLock.lock()
        attentionDebounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard let data = try? Data(contentsOf: URL(filePath: self.attentionFilePath)), !data.isEmpty
            else { return }
            var hasher = Hasher()
            hasher.combine(data)
            let fingerprint = hasher.finalize()
            Task { @MainActor in
                guard fingerprint != self.lastAttentionPayloadFingerprint else { return }
                self.lastAttentionPayloadFingerprint = fingerprint
                self.onAttention?(.cursorStop)
            }
        }
        attentionDebounceWork = work
        attentionDebounceLock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
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

    private func fetchVersion() {
        Task { [weak self] in
            guard let self else { return }
            let version = await self.runShell(
                "PATH=/opt/homebrew/bin:/usr/local/bin:$PATH agent --version 2>/dev/null | head -1")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run { [weak self] in
                self?.versionFetchedVersion = version
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

// MARK: - Hook Setup

/// Manages the user-level `~/.cursor/hooks.json` to include an `afterAgentResponse` hook
/// (for model detection) and a `stop` hook (for notifications) that write their payloads
/// to per-pane temp files identified by the `AGENT_SESSION_MANAGER_PANE_ID` environment variable.
enum CursorHookSetup {
    private static let hookScriptName = "agent-session-manager-cursor-hook.sh"
    private static let stopHookScriptName = "agent-session-manager-cursor-stop-hook.sh"

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
          cat > "/tmp/agent-session-manager-cursor-attention-${AGENT_SESSION_MANAGER_PANE_ID}.json"
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

    /// Ensures `~/.cursor/hooks.json` contains our `afterAgentResponse` and `stop` hooks
    /// and the helper scripts exist. Merges with any existing hooks config non-destructively.
    static func ensureHooksConfigured() {
        do {
            try FileManager.default.createDirectory(at: hooksDirectory, withIntermediateDirectories: true)
            try writeScript(at: hookScriptPath, content: hookScriptContent)
            try writeScript(at: stopHookScriptPath, content: stopHookScriptContent)
            try mergeHooksConfig()
        } catch {
            // Best-effort; model detection and notifications gracefully degrade if hooks aren't set up.
        }
    }

    private static func writeScript(at path: URL, content: String) throws {
        let currentContent = try? String(contentsOf: path, encoding: .utf8)
        if currentContent == content { return }
        try content.write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: path.path)
    }

    private static func mergeHooksConfig() throws {
        let configPath = hooksConfigPath
        var config: [String: Any] = ["version": 1, "hooks": [String: Any]()]

        if let existingData = try? Data(contentsOf: configPath),
            let existing = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]
        {
            config = existing
        }

        var hooks = config["hooks"] as? [String: Any] ?? [:]
        var needsWrite = false

        needsWrite =
            installHookEntry(
                into: &hooks,
                eventName: "afterAgentResponse",
                entry: hookEntry,
                scriptName: hookScriptName
            ) || needsWrite

        needsWrite =
            installHookEntry(
                into: &hooks,
                eventName: "stop",
                entry: stopHookEntry,
                scriptName: stopHookScriptName
            ) || needsWrite

        if needsWrite {
            config["hooks"] = hooks
            if config["version"] == nil { config["version"] = 1 }
            let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: configPath, options: .atomic)
        }
    }

    /// Returns `true` if the entry was added (config needs writing).
    @discardableResult
    private static func installHookEntry(
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
