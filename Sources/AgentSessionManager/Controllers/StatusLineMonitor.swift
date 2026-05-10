import AppKit
import Foundation
import Observation

enum SidebarSide: String, Codable, CaseIterable {
    case left, right

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

@Observable
@MainActor
final class StatusLineMonitor {
    private(set) var currentData: StatusLineData?

    private let paneID: UUID
    let filePath: String
    let settingsFilePath: String
    /// Written by Claude Code `Notification` hook stdin when `isClaudeHookAttentionEnabled` is on.
    let attentionSignalFilePath: String
    private let workingDirectory: String?
    private let cliType: CLIType
    private let isClaude: Bool
    private var source: DispatchSourceFileSystemObject?
    private var attentionSource: DispatchSourceFileSystemObject?
    private let attentionDebounceLock = NSLock()
    private var attentionDebounceWork: DispatchWorkItem?
    private var lastAttentionPayloadFingerprint: Int?
    private var prTimer: Timer?
    private var prQueryTask: Process?
    /// Bumped when starting a new query or in `stop()` so older `terminationHandler` callbacks cannot mutate `currentData`.
    private var prQueryToken: UInt64 = 0
    private var agnosticProvider: ToolAgnosticDataProvider?

    /// Fires on the main actor when the Claude `Notification` hook rewrites ``attentionSignalFilePath`` (debounced).
    var onClaudeHookAttention: (() -> Void)?

    init(paneID: UUID, workingDirectory: String? = nil, cliType: CLIType, processStartTime: Date = Date()) {
        self.paneID = paneID
        self.workingDirectory = workingDirectory
        self.cliType = cliType
        self.isClaude = cliType == .claude
        filePath = NSTemporaryDirectory() + "agent-session-manager-status-\(paneID.uuidString).json"
        settingsFilePath = NSTemporaryDirectory() + "agent-session-manager-settings-\(paneID.uuidString).json"
        attentionSignalFilePath =
            NSTemporaryDirectory() + "agent-session-manager-claude-attention-\(paneID.uuidString).json"

        if !isClaude, let cwd = workingDirectory {
            let toolCmd = cliType.cliCommandDescription
            agnosticProvider = ToolAgnosticDataProvider(
                workingDirectory: cwd, toolCommand: toolCmd, processStartTime: processStartTime)
            agnosticProvider?.onUpdate = { [weak self] data in
                guard let self else { return }
                var merged = data
                if let existing = self.currentData?.pr {
                    merged.pr = existing
                }
                self.currentData = merged
            }
        }
    }

    func start() {
        if isClaude {
            writeSettingsFile()
            FileManager.default.createFile(atPath: filePath, contents: nil)

            let fd = open(filePath, O_EVTONLY)
            guard fd >= 0 else { return }

            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend],
                queue: .global(qos: .utility)
            )
            src.setEventHandler { [weak self, filePath] in
                guard let data = try? Data(contentsOf: URL(filePath: filePath)),
                    let parsed = try? JSONDecoder().decode(StatusLineData.self, from: data)
                else { return }
                Task { @MainActor [weak self] in
                    var merged = parsed
                    if let existing = self?.currentData?.pr {
                        merged.pr = existing
                    }
                    self?.currentData = merged
                }
            }
            src.setCancelHandler { close(fd) }
            src.resume()
            source = src

            restartAttentionWatcherIfEligible()
        } else {
            agnosticProvider?.start()
        }

        queryPR()
        prTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.queryPR()
            }
        }
    }

    /// Rewrites Claude `--settings` and restarts the attention file watcher (e.g. when the user toggles the hook in Settings).
    func refreshClaudeIntegrationFromSettings() {
        guard isClaude else { return }
        writeSettingsFile()
        restartAttentionWatcherIfEligible()
    }

    func stop() {
        source?.cancel()
        source = nil
        stopAttentionWatcher()
        agnosticProvider?.stop()
        agnosticProvider = nil
        prTimer?.invalidate()
        prTimer = nil
        prQueryToken += 1
        prQueryTask?.terminate()
        prQueryTask = nil
        try? FileManager.default.removeItem(atPath: filePath)
        try? FileManager.default.removeItem(atPath: settingsFilePath)
        try? FileManager.default.removeItem(atPath: attentionSignalFilePath)
    }

    private func writeSettingsFile() {
        let attentionEnabled = isClaude && SettingsPersistence.isClaudeHookAttentionEnabled()
        var settings: [String: Any] = [
            "statusLine": [
                "type": "command",
                "command": "cat > '\(filePath)'",
            ]
        ]
        if attentionEnabled {
            settings["hooks"] = [
                "Notification": [
                    [
                        "matcher": "",
                        "hooks": [
                            [
                                "type": "command",
                                "command": "cat > '\(attentionSignalFilePath)'",
                            ]
                        ],
                    ]
                ]
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted) else { return }
        try? data.write(to: URL(filePath: settingsFilePath))
    }

    private func restartAttentionWatcherIfEligible() {
        stopAttentionWatcher()
        guard isClaude, SettingsPersistence.isClaudeHookAttentionEnabled() else { return }
        FileManager.default.createFile(atPath: attentionSignalFilePath, contents: nil)
        let fd = open(attentionSignalFilePath, O_EVTONLY)
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
            guard let data = try? Data(contentsOf: URL(filePath: self.attentionSignalFilePath)), !data.isEmpty else {
                return
            }
            var hasher = Hasher()
            hasher.combine(data)
            let fingerprint = hasher.finalize()
            Task { @MainActor in
                guard fingerprint != self.lastAttentionPayloadFingerprint else { return }
                self.lastAttentionPayloadFingerprint = fingerprint
                if DebugLogger.shared.acceptsPaneDiagnostics(paneID: self.paneID) || DebugLogger.shared.isEnabled {
                    DebugLogger.shared.log(
                        "[notify] Claude Notification hook stdin written to attention file (\(data.count) bytes)",
                        paneID: self.paneID,
                        tabName: "",
                        paneName: ""
                    )
                }
                self.onClaudeHookAttention?()
            }
        }
        attentionDebounceWork = work
        attentionDebounceLock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    @MainActor
    private func queryPR() {
        guard SettingsPersistence.isPRTrackingEnabled() else {
            currentData?.pr = nil
            return
        }
        guard let workingDirectory else { return }
        prQueryTask?.terminate()
        prQueryToken += 1
        let token = prQueryToken

        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.executableURL = URL(filePath: "/bin/zsh")
        task.arguments = [
            "-c",
            "cd '\(workingDirectory)' && branch=$(git branch --show-current 2>/dev/null) && [ -n \"$branch\" ] && gh pr view \"$branch\" --json number,title,state,url 2>/dev/null || true",
        ]
        task.standardOutput = outPipe
        task.standardError = errPipe

        task.terminationHandler = { _ in
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor [weak self] in
                guard let self, token == self.prQueryToken else { return }
                self.applyPROutputIfValid(outData)
            }
        }

        prQueryTask = task
        do {
            try task.run()
        } catch {
            return
        }
    }

    @MainActor
    private func applyPROutputIfValid(_ outData: Data) {
        guard !outData.isEmpty else { return }
        guard let pr = try? JSONDecoder().decode(PullRequest.self, from: outData) else { return }
        if currentData == nil {
            currentData = StatusLineData(
                model: nil, cost: nil, contextWindow: nil, rateLimits: nil,
                worktree: nil, workspace: nil, effort: nil, thinking: nil,
                agent: nil, outputStyle: nil, vim: nil,
                sessionName: nil, version: nil, exceeds200kTokens: nil,
                pr: pr
            )
        } else {
            currentData?.pr = pr
        }
    }

    /// Builds the per-pane Claude `settings` dictionary (`statusLine` plus optional `hooks`) for tests and tooling.
    nonisolated static func makeClaudeSettingsDictionaryForTesting(
        statusOutputPath: String,
        attentionOutputPath: String,
        includeNotificationHook: Bool
    ) -> [String: Any] {
        var settings: [String: Any] = [
            "statusLine": [
                "type": "command",
                "command": "cat > '\(statusOutputPath)'",
            ]
        ]
        if includeNotificationHook {
            settings["hooks"] = [
                "Notification": [
                    [
                        "matcher": "",
                        "hooks": [
                            [
                                "type": "command",
                                "command": "cat > '\(attentionOutputPath)'",
                            ]
                        ],
                    ]
                ]
            ]
        }
        return settings
    }
}

/// Runs `/bin/zsh -c` and returns stdout after exit; drains stderr so pipes cannot fill. Used by `StatusLineMonitor` tests and mirrors production I/O behavior.
enum PRQueryShellIO {
    static func zshCollectOutput(script: String, currentDirectory: URL?) throws -> Data {
        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.executableURL = URL(filePath: "/bin/zsh")
        task.arguments = ["-c", script]
        task.currentDirectoryURL = currentDirectory
        task.standardOutput = outPipe
        task.standardError = errPipe
        try task.run()
        task.waitUntilExit()
        _ = errPipe.fileHandleForReading.readDataToEndOfFile()
        return outPipe.fileHandleForReading.readDataToEndOfFile()
    }
}
