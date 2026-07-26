import Darwin
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
    let hookDirectoryPath: String
    let hookOutputFilePath: String
    let attentionFilePath: String
    let lifecycleFilePath: String

    private var refreshTimer: Timer?
    private var versionFetchedVersion: String?
    private var hookSource: DispatchSourceFileSystemObject?
    private var attentionSource: DispatchSourceFileSystemObject?
    private var lifecycleSource: DispatchSourceFileSystemObject?
    private var lastHookModel: StatusLineData.Model?
    private var activeConversationID: String?
    private var activeGenerationID: String?
    private let attentionDebounceLock = NSLock()
    private var attentionDebounceWork: DispatchWorkItem?
    private var lastAttentionPayloadFingerprint: Int?
    private var isStopping = false
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
        self.hookDirectoryPath =
            NSTemporaryDirectory() + "agent-session-manager-cursor-\(UUID().uuidString)"
        self.hookOutputFilePath =
            hookDirectoryPath + "/hook.json"
        self.attentionFilePath =
            hookDirectoryPath + "/attention.json"
        self.lifecycleFilePath =
            hookDirectoryPath + "/lifecycle.json"
    }

    func start() {
        isStopping = false
        activeConversationID = nil
        activeGenerationID = nil
        var hookSetupError: Error?
        do {
            try FileManager.default.createDirectory(
                atPath: hookDirectoryPath,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: hookDirectoryPath)
        } catch {
            hookSetupError = error
        }
        if hookSetupError == nil {
            do {
                try CursorHookSetup.acquire(owner: paneID)
            } catch {
                hookSetupError = error
            }
        }
        if let hookSetupError {
            TracingService.shared.record(
                "statusline.cursor.hook_setup_failed",
                attributes: cursorTraceAttributes([
                    "error": hookSetupError.localizedDescription,
                    "result": "degraded",
                ]))
        }
        FileManager.default.createFile(atPath: hookOutputFilePath, contents: nil)
        FileManager.default.createFile(atPath: attentionFilePath, contents: nil)
        FileManager.default.createFile(atPath: lifecycleFilePath, contents: nil)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: hookOutputFilePath)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: attentionFilePath)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: lifecycleFilePath)
        startHookWatcher()
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
        isStopping = true
        refreshTimer?.invalidate()
        refreshTimer = nil
        hookSource?.cancel()
        hookSource = nil
        lifecycleSource?.cancel()
        lifecycleSource = nil
        CursorHookSetup.release(owner: paneID)
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
        try? FileManager.default.removeItem(atPath: hookDirectoryPath)
        activeConversationID = nil
        activeGenerationID = nil
    }

    var hookEnvironmentVariables: [String: String] {
        ["AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR": hookDirectoryPath]
    }

    func configureAttentionWatcher(enabled: Bool) {
        attentionDebounceLock.lock()
        attentionDebounceWork?.cancel()
        attentionDebounceWork = nil
        attentionDebounceLock.unlock()
        attentionSource?.cancel()
        attentionSource = nil
        lastAttentionPayloadFingerprint = nil
        guard enabled, !isStopping else { return }

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
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self, weak source] in
            let inodeLost = source?.data.isDisjoint(with: [.delete, .rename, .revoke]) == false
            if inodeLost {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.configureAttentionWatcher(enabled: true)
                    self.scheduleAttentionPayloadRead()
                }
                return
            }
            Task { @MainActor [weak self] in
                self?.scheduleAttentionPayloadRead()
            }
        }
        source.setCancelHandler { close(attentionFD) }
        source.resume()
        attentionSource = source
        TracingService.shared.record(
            "statusline.cursor.attention_watcher.started",
            attributes: cursorTraceAttributes([:]))
    }

    private func scheduleAttentionPayloadRead() {
        attentionDebounceLock.lock()
        attentionDebounceWork?.cancel()
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
        attentionDebounceWork = work
        attentionDebounceLock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    var currentDurationMs: Double {
        max(0, Date().timeIntervalSince(processStartTime)) * 1000
    }

    private func startLifecycleWatcher() {
        guard !isStopping else { return }
        lifecycleSource?.cancel()
        lifecycleSource = nil
        let lifecycleFD = open(lifecycleFilePath, O_EVTONLY)
        guard lifecycleFD >= 0 else {
            TracingService.shared.record(
                "statusline.cursor.lifecycle_watcher.failed",
                attributes: cursorTraceAttributes(["reason": "open_failed"]))
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: lifecycleFD,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self, weak source] in
            let inodeLost = source?.data.isDisjoint(with: [.delete, .rename, .revoke]) == false
            if inodeLost {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.startLifecycleWatcher()
                    self.readLifecyclePayload()
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.readLifecyclePayload()
                }
            }
        }
        source.setCancelHandler { close(lifecycleFD) }
        source.resume()
        lifecycleSource = source
        TracingService.shared.record(
            "statusline.cursor.lifecycle_watcher.started",
            attributes: cursorTraceAttributes([:]))
    }

    private func startHookWatcher() {
        guard !isStopping else { return }
        hookSource?.cancel()
        hookSource = nil
        let hookFD = open(hookOutputFilePath, O_EVTONLY)
        guard hookFD >= 0 else {
            TracingService.shared.record(
                "statusline.cursor.hook_watcher.failed",
                attributes: cursorTraceAttributes(["reason": "open_failed"]))
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: hookFD,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self, weak source] in
            let inodeLost = source?.data.isDisjoint(with: [.delete, .rename, .revoke]) == false
            if inodeLost {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.startHookWatcher()
                    self.readHookPayload()
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.readHookPayload()
                }
            }
        }
        source.setCancelHandler { close(hookFD) }
        source.resume()
        hookSource = source
    }

    private func readHookPayload() {
        guard let data = try? Data(contentsOf: URL(filePath: hookOutputFilePath)),
            !data.isEmpty,
            let parsed = CursorHookPayload.parse(data)
        else { return }
        let model = StatusLineData.Model(id: parsed.model, displayName: parsed.model)
        lastHookModel = model
        refreshNow()
    }

    private func readLifecyclePayload() {
        guard let data = try? Data(contentsOf: URL(filePath: lifecycleFilePath)),
            let payload = CursorLifecyclePayload.parse(data)
        else { return }
        applyLifecyclePayload(payload)
    }

    func applyLifecyclePayload(_ payload: CursorLifecyclePayload) {
        let isWorking = payload.hookEventName == "beforeSubmitPrompt"
        if isWorking {
            activeConversationID = payload.conversationID
            activeGenerationID = payload.generationID
        } else {
            if let activeConversationID, let eventConversationID = payload.conversationID,
                activeConversationID != eventConversationID
            {
                recordIgnoredLifecycle(payload, reason: "conversation_mismatch")
                return
            }
            if let activeGenerationID, let eventGenerationID = payload.generationID,
                activeGenerationID != eventGenerationID
            {
                recordIgnoredLifecycle(payload, reason: "generation_mismatch")
                return
            }
        }
        TracingService.shared.record(
            "statusline.cursor.lifecycle.received",
            attributes: cursorTraceAttributes([
                "hook_event": payload.hookEventName,
                "state": isWorking ? "working" : "stopped",
                "conversation_id_prefix": payload.conversationID.map { String($0.prefix(12)) } ?? "nil",
                "generation_id_prefix": payload.generationID.map { String($0.prefix(12)) } ?? "nil",
            ]))
        onActivityChanged?(isWorking)
    }

    private func recordIgnoredLifecycle(_ payload: CursorLifecyclePayload, reason: String) {
        TracingService.shared.record(
            "statusline.cursor.lifecycle.ignored",
            attributes: cursorTraceAttributes([
                "hook_event": payload.hookEventName,
                "reason": reason,
                "conversation_id_prefix": payload.conversationID.map { String($0.prefix(12)) } ?? "nil",
                "generation_id_prefix": payload.generationID.map { String($0.prefix(12)) } ?? "nil",
            ]))
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
    let conversationID: String?
    let generationID: String?

    static func parse(_ data: Data) -> CursorLifecyclePayload? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hookEventName = dict["hook_event_name"] as? String,
            !hookEventName.isEmpty
        else { return nil }
        return CursorLifecyclePayload(
            hookEventName: hookEventName,
            conversationID: dict["conversation_id"] as? String,
            generationID: dict["generation_id"] as? String
        )
    }
}

// MARK: - Hook Setup

/// Manages the user-level `~/.cursor/hooks.json` to include an `afterAgentResponse` hook
/// (for model detection) and a `stop` hook (for notifications) that write their payloads
/// to per-pane temp files identified by the `AGENT_SESSION_MANAGER_PANE_ID` environment variable.
enum CursorHookSetup {
    struct HookEntry: Sendable, Equatable {
        let command: String

        var jsonObject: [String: Any] {
            ["command": command]
        }
    }

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

    static var hooksLockPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".cursor/agent-session-manager-hooks.lock")
    }

    /// The hook script reads stdin (the JSON payload from Cursor) and writes it to a
    /// private per-pane directory passed through the environment.
    static let hookScriptContent = """
        #!/bin/bash
        umask 077
        if [ -n "$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR" ]; then
          temporary="$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/.hook.json.$$"
          if cat > "$temporary"; then
            mv -f "$temporary" "$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/hook.json"
          else
            rm -f "$temporary"
          fi
        else
          cat > /dev/null
        fi
        exit 0

        """

    /// The stop hook writes its payload to the per-pane attention file, triggering a notification.
    static let stopHookScriptContent = """
        #!/bin/bash
        umask 077
        if [ -n "$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR" ]; then
          temporary="$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/.stop.json.$$"
          attentionTemporary="$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/.attention.json.$$"
          lifecycleTemporary="$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/.lifecycle.json.$$"
          if cat > "$temporary" \
            && cp "$temporary" "$attentionTemporary" \
            && cp "$temporary" "$lifecycleTemporary"; then
            mv -f "$attentionTemporary" "$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/attention.json"
            mv -f "$lifecycleTemporary" "$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/lifecycle.json"
          fi
          rm -f "$temporary" "$attentionTemporary" "$lifecycleTemporary"
        else
          cat > /dev/null
        fi
        exit 0

        """

    static let lifecycleHookScriptContent = """
        #!/bin/bash
        umask 077
        if [ -n "$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR" ]; then
          temporary="$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/.lifecycle.json.$$"
          if cat > "$temporary"; then
            mv -f "$temporary" "$AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR/lifecycle.json"
          else
            rm -f "$temporary"
          fi
        else
          cat > /dev/null
        fi
        exit 0

        """

    static let hookEntry = HookEntry(command: "./hooks/\(hookScriptName)")

    static let stopHookEntry = HookEntry(command: "./hooks/\(stopHookScriptName)")

    static let lifecycleHookEntry = HookEntry(command: "./hooks/\(lifecycleHookScriptName)")

    private static let ownershipLock = NSLock()
    nonisolated(unsafe) private static var activeOwners = Set<UUID>()

    static func acquire(owner: UUID) throws {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard !activeOwners.contains(owner) else { return }

        if activeOwners.isEmpty {
            try FileManager.default.createDirectory(
                at: hooksDirectory, withIntermediateDirectories: true)
            let lockFD = open(hooksLockPath.path, O_CREAT | O_RDWR, 0o600)
            guard lockFD >= 0 else {
                throw NSError(
                    domain: "CursorHookSetup", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not open Cursor hooks lock"])
            }
            guard flock(lockFD, LOCK_EX) == 0 else {
                close(lockFD)
                throw NSError(
                    domain: "CursorHookSetup", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Could not lock Cursor hooks configuration"])
            }
            defer {
                flock(lockFD, LOCK_UN)
                close(lockFD)
            }
            try writeScript(at: hookScriptPath, content: hookScriptContent)
            try writeScript(at: stopHookScriptPath, content: stopHookScriptContent)
            try writeScript(at: lifecycleHookScriptPath, content: lifecycleHookScriptContent)

            var config: [String: Any] = ["version": 1, "hooks": [String: Any]()]
            if let existingData = try? Data(contentsOf: hooksConfigPath) {
                guard let existing = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]
                else {
                    throw NSError(
                        domain: "CursorHookSetup", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Cursor hooks configuration is not valid JSON"])
                }
                config = existing
            }
            var hooks = config["hooks"] as? [String: Any] ?? [:]
            var needsWrite = false
            needsWrite =
                installHookEntry(
                    into: &hooks,
                    eventName: "beforeSubmitPrompt",
                    entry: lifecycleHookEntry,
                    scriptName: lifecycleHookScriptName
                ) || needsWrite
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
                let data = try JSONSerialization.data(
                    withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: hooksConfigPath, options: .atomic)
            }
        }
        activeOwners.insert(owner)
        TracingService.shared.record(
            "statusline.cursor.hooks.owner_acquired",
            attributes: ["owner_count": "\(activeOwners.count)"])
    }

    static func release(owner: UUID) {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard activeOwners.remove(owner) != nil, activeOwners.isEmpty else { return }

        do {
            let lockFD = open(hooksLockPath.path, O_CREAT | O_RDWR, 0o600)
            guard lockFD >= 0 else {
                throw NSError(
                    domain: "CursorHookSetup", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Could not open Cursor hooks lock"])
            }
            guard flock(lockFD, LOCK_EX) == 0 else {
                close(lockFD)
                throw NSError(
                    domain: "CursorHookSetup", code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Could not lock Cursor hooks configuration"])
            }
            defer {
                flock(lockFD, LOCK_UN)
                close(lockFD)
            }
            var config =
                try JSONSerialization.jsonObject(with: Data(contentsOf: hooksConfigPath)) as? [String: Any] ?? [:]
            var hooks = config["hooks"] as? [String: Any] ?? [:]
            var needsWrite = false
            for (eventName, scriptName) in [
                ("beforeSubmitPrompt", lifecycleHookScriptName),
                ("afterAgentResponse", hookScriptName),
                ("stop", stopHookScriptName),
            ] {
                guard var entries = hooks[eventName] as? [[String: Any]] else { continue }
                let filtered = entries.filter {
                    ($0["command"] as? String) != "./hooks/\(scriptName)"
                }
                if filtered.count != entries.count {
                    entries = filtered
                    hooks[eventName] = entries
                    needsWrite = true
                }
            }
            if needsWrite {
                config["hooks"] = hooks
                let data = try JSONSerialization.data(
                    withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: hooksConfigPath, options: .atomic)
            }
            for (path, content) in [
                (hookScriptPath, hookScriptContent),
                (stopHookScriptPath, stopHookScriptContent),
                (lifecycleHookScriptPath, lifecycleHookScriptContent),
            ] {
                if let existing = try? String(contentsOf: path, encoding: .utf8), existing == content {
                    try? FileManager.default.removeItem(at: path)
                }
            }
            TracingService.shared.record(
                "statusline.cursor.hooks.released",
                attributes: ["owner_count": "0"])
        } catch {
            TracingService.shared.record(
                "statusline.cursor.hooks.release_failed",
                attributes: [
                    "owner_count": "0",
                    "error": error.localizedDescription,
                ])
        }
    }

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
        entry: HookEntry,
        scriptName: String
    ) -> Bool {
        var entries = hooks[eventName] as? [[String: Any]] ?? []
        let alreadyInstalled = entries.contains {
            ($0["command"] as? String)?.contains(scriptName) == true
        }
        guard !alreadyInstalled else { return false }
        entries.append(entry.jsonObject)
        hooks[eventName] = entries
        return true
    }
}
