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
    private var agnosticProvider: (any StatusLineDataProvider)?

    /// Fires on the main actor when the Claude `Notification` hook rewrites ``attentionSignalFilePath`` (debounced).
    var onClaudeHookAttention: (() -> Void)?
    /// Fires on the main actor when a PR transitions from a non-merged state to "merged".
    var onPRMerged: ((_ prNumber: Int, _ prTitle: String) -> Void)?

    private var lastKnownPRState: String?
    private var hasFiredMergedNotification = false

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
            let provider: any StatusLineDataProvider
            if cliType == .opencode {
                provider = OpenCodeDataProvider(workingDirectory: cwd, processStartTime: processStartTime)
            } else if cliType == .cursor {
                provider = CursorDataProvider(
                    workingDirectory: cwd, paneID: paneID, processStartTime: processStartTime)
            } else {
                let toolCmd = cliType.cliCommandDescription
                provider = ToolAgnosticDataProvider(
                    workingDirectory: cwd, toolCommand: toolCmd, processStartTime: processStartTime)
            }
            agnosticProvider = provider
            agnosticProvider?.onUpdate = { [weak self] data in
                guard let self else { return }
                var merged = data
                if let existing = self.currentData?.pr {
                    merged.pr = existing
                }
                self.currentData = merged
            }
            agnosticProvider?.onAttention = { [weak self] in
                Task { @MainActor in
                    self?.onClaudeHookAttention?()
                }
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

        if let cwd = workingDirectory {
            PRTrackingCoordinator.shared.subscribe(
                paneID: paneID,
                workingDirectory: cwd,
                isActive: true
            ) { [weak self] pr in
                guard let self else { return }
                if self.currentData == nil {
                    self.currentData = StatusLineData(
                        model: nil, cost: nil, contextWindow: nil, rateLimits: nil,
                        worktree: nil, workspace: nil, effort: nil, thinking: nil,
                        agent: nil, outputStyle: nil, vim: nil,
                        sessionName: nil, version: nil, exceeds200kTokens: nil,
                        sessionStatus: nil, openCodeMode: nil,
                        pr: pr
                    )
                } else {
                    self.currentData?.pr = pr
                }
                self.checkForMergedTransition(pr)
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
        PRTrackingCoordinator.shared.unsubscribe(paneID: paneID)
        lastKnownPRState = nil
        hasFiredMergedNotification = false
        try? FileManager.default.removeItem(atPath: filePath)
        try? FileManager.default.removeItem(atPath: settingsFilePath)
        try? FileManager.default.removeItem(atPath: attentionSignalFilePath)
    }

    private func writeSettingsFile() {
        let attentionEnabled = isClaude && SettingsPersistence.isClaudeHookAttentionEnabled()
        let prTrackingEnabled = SettingsPersistence.isPRTrackingEnabled()
        var settings: [String: Any] = [
            "statusLine": [
                "type": "command",
                "command": "cat > '\(filePath)'",
            ]
        ]
        if prTrackingEnabled {
            settings["showPRStatus"] = false
        }
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
    private func applyPROutputIfValid(_ outData: Data) {
        guard !outData.isEmpty else {
            DebugLogger.shared.log("[pr] applyPROutput skipped: empty data", paneID: paneID)
            return
        }
        guard let pr = try? JSONDecoder().decode(PullRequest.self, from: outData) else {
            DebugLogger.shared.log("[pr] applyPROutput decode failed", paneID: paneID)
            return
        }
        DebugLogger.shared.log(
            "[pr] applyPROutput decoded pr=#\(pr.number) state=\(pr.state) isDraft=\(pr.isDraft ?? false)",
            paneID: paneID
        )
        if currentData == nil {
            currentData = StatusLineData(
                model: nil, cost: nil, contextWindow: nil, rateLimits: nil,
                worktree: nil, workspace: nil, effort: nil, thinking: nil,
                agent: nil, outputStyle: nil, vim: nil,
                sessionName: nil, version: nil, exceeds200kTokens: nil,
                sessionStatus: nil, openCodeMode: nil,
                pr: pr
            )
        } else {
            currentData?.pr = pr
        }
        checkForMergedTransition(pr)
    }

    @MainActor
    private func checkForMergedTransition(_ pr: PullRequest?) {
        guard let pr else { return }
        let newState = pr.state.lowercased()
        DebugLogger.shared.log(
            "[pr] checkMergedTransition state=\(newState) lastKnown=\(lastKnownPRState ?? "nil") hasFired=\(hasFiredMergedNotification)",
            paneID: paneID
        )
        defer { lastKnownPRState = newState }
        guard !hasFiredMergedNotification else { return }
        guard newState == "merged" else { return }
        // Suppress on first observation (app launch/restart) — only fire on a live transition.
        guard lastKnownPRState != nil else { return }
        guard lastKnownPRState != "merged" else { return }
        hasFiredMergedNotification = true
        onPRMerged?(pr.number, pr.title)
    }

    /// For testing only: simulates a PR data update as if received from `gh pr view`.
    @MainActor
    func simulatePRUpdateForTesting(_ data: Data) {
        applyPROutputIfValid(data)
    }

    /// Builds the per-pane Claude `settings` dictionary (`statusLine` plus optional `hooks`) for tests and tooling.
    nonisolated static func makeClaudeSettingsDictionaryForTesting(
        statusOutputPath: String,
        attentionOutputPath: String,
        includeNotificationHook: Bool,
        hidePRStatus: Bool = false
    ) -> [String: Any] {
        var settings: [String: Any] = [
            "statusLine": [
                "type": "command",
                "command": "cat > '\(statusOutputPath)'",
            ]
        ]
        if hidePRStatus {
            settings["showPRStatus"] = false
        }
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
