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
    private(set) var isClaudeWorking = false

    private let paneID: UUID
    private let paneName: String
    private let tabID: UUID
    private let tabName: String
    let filePath: String
    let settingsFilePath: String
    /// Written by Claude Code attention hooks so user-blocking interactions use the notification path.
    let attentionSignalFilePath: String
    /// Written by Claude Code lifecycle hooks so activity does not depend on noisy PTY reads.
    let activitySignalFilePath: String
    private let workingDirectory: String?
    private let harness: Harness
    private let isClaude: Bool
    private var source: DispatchSourceFileSystemObject?
    private var attentionSource: DispatchSourceFileSystemObject?
    private var activitySource: DispatchSourceFileSystemObject?
    private let attentionDebounceLock = NSLock()
    private var attentionDebounceWork: DispatchWorkItem?
    private var lastAttentionPayloadFingerprint: Int?
    private var agnosticProvider: (any StatusLineDataProvider)?
    private var gitDiffTimer: Timer?
    private var cachedGitStats: (added: Int, removed: Int) = (0, 0)
    private var lastAppliedModificationDate: Date?

    /// Fires on the main actor when the Claude `Notification` hook rewrites ``attentionSignalFilePath`` (debounced).
    var onClaudeHookAttention: ((PaneAttentionEvent) -> Void)?
    /// Fires on the main actor when a PR transitions from a non-merged state to "merged".
    var onPRMerged: ((_ prNumber: Int, _ prTitle: String) -> Void)?

    private var lastKnownPRState: String?
    private var hasFiredMergedNotification = false

    init(
        paneID: UUID,
        paneName: String = "",
        workingDirectory: String? = nil,
        harness: Harness,
        processStartTime: Date = Date(),
        tabID: UUID = UUID(),
        tabName: String = ""
    ) {
        self.paneID = paneID
        self.paneName = paneName.isEmpty ? String(paneID.uuidString.prefix(8)) : paneName
        self.tabID = tabID
        self.tabName = tabName
        self.workingDirectory = workingDirectory
        self.harness = harness
        self.isClaude = harness == .claude
        filePath = NSTemporaryDirectory() + "agent-session-manager-status-\(paneID.uuidString).json"
        settingsFilePath = NSTemporaryDirectory() + "agent-session-manager-settings-\(paneID.uuidString).json"
        attentionSignalFilePath =
            NSTemporaryDirectory() + "agent-session-manager-claude-attention-\(paneID.uuidString).json"
        activitySignalFilePath =
            NSTemporaryDirectory() + "agent-session-manager-claude-activity-\(paneID.uuidString).json"

        if !isClaude, let cwd = workingDirectory {
            let provider: any StatusLineDataProvider
            if harness == .cursor {
                provider = CursorDataProvider(
                    workingDirectory: cwd, paneID: paneID, processStartTime: processStartTime)
            } else {
                let toolCmd = harness.commandDescription
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
            agnosticProvider?.onAttention = { [weak self] event in
                Task { @MainActor in
                    guard let self else { return }
                    TracingService.shared.record(
                        "statusline.attention.received",
                        attributes: [
                            "pane.name": self.paneName, "pane.id": self.paneID.uuidString,
                            "tab.id": self.tabID.uuidString, "tab.name": self.tabName,
                            "source": event.source.rawValue, "reason": event.reason,
                        ])
                    self.onClaudeHookAttention?(event)
                }
            }
        }
    }

    func start() {
        if isClaude {
            writeSettingsFile()
            TracingService.shared.record(
                "statusline.monitor.started",
                attributes: [
                    "pane.name": paneName,
                    "pane.id": paneID.uuidString,
                    "tab.id": tabID.uuidString,
                    "tab.name": tabName,
                ])
            FileManager.default.createFile(atPath: filePath, contents: nil)
            FileManager.default.createFile(atPath: activitySignalFilePath, contents: nil)

            startStatusWatcher()
            startActivityWatcher()

            if let cwd = workingDirectory {
                scheduleGitDiffPolling(workingDirectory: cwd)
            }

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
                        pr: pr
                    )
                } else {
                    self.currentData?.pr = pr
                }
                self.checkForMergedTransition(pr)
            }
        }
    }

    /// Rewrites Claude `--settings` after an integration-affecting setting changes.
    func refreshClaudeIntegrationFromSettings() {
        guard isClaude else { return }
        writeSettingsFile()
    }

    func stop() {
        source?.cancel()
        source = nil
        activitySource?.cancel()
        activitySource = nil
        gitDiffTimer?.invalidate()
        gitDiffTimer = nil
        TracingService.shared.record(
            "statusline.monitor.stopped",
            attributes: [
                "pane.name": paneName,
                "pane.id": paneID.uuidString,
                "tab.id": tabID.uuidString,
                "tab.name": tabName,
            ])
        stopAttentionWatcher()
        agnosticProvider?.stop()
        agnosticProvider = nil
        PRTrackingCoordinator.shared.unsubscribe(paneID: paneID)
        lastKnownPRState = nil
        hasFiredMergedNotification = false
        try? FileManager.default.removeItem(atPath: filePath)
        try? FileManager.default.removeItem(atPath: settingsFilePath)
        try? FileManager.default.removeItem(atPath: attentionSignalFilePath)
        try? FileManager.default.removeItem(atPath: activitySignalFilePath)
    }

    private func scheduleGitDiffPolling(workingDirectory: String) {
        Task { [weak self] in
            guard let self else { return }
            if let stats = await GitDiffStats.compute(in: workingDirectory) {
                await MainActor.run { self.cachedGitStats = stats }
            }
        }
        gitDiffTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                if let stats = await GitDiffStats.compute(in: workingDirectory) {
                    await MainActor.run { self.cachedGitStats = stats }
                }
                await MainActor.run { self.checkPayloadFreshness() }
            }
        }
    }

    private func startStatusWatcher() {
        source?.cancel()
        source = nil
        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else { return }
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .global(qos: .utility)
        )
        newSource.setEventHandler { [weak self, weak newSource] in
            guard let self else { return }
            let inodeLost = newSource?.data.isDisjoint(with: [.delete, .rename, .revoke]) == false
            if inodeLost {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.startStatusWatcher()
                    self.applyLatestPayload(reason: "vnode_reopen")
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.applyLatestPayload(reason: "vnode_write")
                }
            }
        }
        newSource.setCancelHandler { close(fd) }
        newSource.resume()
        source = newSource
    }

    @MainActor
    private func applyLatestPayload(reason: String) {
        let url = URL(filePath: filePath)
        let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
        let mtime = attrs?[.modificationDate] as? Date

        let rawData: Data
        do {
            rawData = try Data(contentsOf: url)
        } catch {
            TracingService.shared.record(
                "statusline.payload.decode_failed",
                attributes: [
                    "pane.name": paneName, "pane.id": paneID.uuidString,
                    "tab.id": tabID.uuidString, "tab.name": tabName,
                    "reason": reason,
                    "error": "read_failed:\(error.localizedDescription)", "byte_count": "0",
                ])
            return
        }

        guard !rawData.isEmpty else { return }

        let parsed: StatusLineData
        do {
            parsed = try JSONDecoder().decode(StatusLineData.self, from: rawData)
        } catch {
            let prefix = String(decoding: rawData.prefix(120), as: UTF8.self)
            TracingService.shared.record(
                "statusline.payload.decode_failed",
                attributes: [
                    "pane.name": paneName, "pane.id": paneID.uuidString,
                    "tab.id": tabID.uuidString, "tab.name": tabName,
                    "reason": reason,
                    "error": error.localizedDescription,
                    "byte_count": "\(rawData.count)",
                    "payload_prefix": prefix,
                ])
            return
        }

        var enforced = parsed
        if let existing = currentData?.pr {
            enforced.pr = existing
        }
        applyI1Enforcement(to: &enforced)
        applyI3Enforcement(to: &enforced)
        currentData = enforced
        lastAppliedModificationDate = mtime ?? Date()

        let inode = attrs?[.systemFileNumber] as? Int
        TracingService.shared.record(
            "statusline.payload.applied",
            attributes: [
                "pane.name": paneName, "pane.id": paneID.uuidString,
                "tab.id": tabID.uuidString, "tab.name": tabName,
                "reason": reason,
                "cost_usd": enforced.cost?.totalCostUsd.map { String(format: "%.4f", $0) } ?? "nil",
                "used_pct": enforced.contextWindow?.usedPercentage.map { "\($0)" } ?? "nil",
                "inode": inode.map { "\($0)" } ?? "unknown",
            ])
    }

    @MainActor
    private func checkPayloadFreshness() {
        guard let mtime = (try? FileManager.default.attributesOfItem(atPath: filePath))?[.modificationDate] as? Date
        else { return }
        guard let lastApplied = lastAppliedModificationDate else {
            applyLatestPayload(reason: "freshness_initial")
            return
        }
        guard mtime > lastApplied else { return }
        let staleAge = -mtime.timeIntervalSinceNow
        TracingService.shared.record(
            "statusline.payload.stale_recovered",
            attributes: [
                "pane.name": paneName, "pane.id": paneID.uuidString,
                "tab.id": tabID.uuidString, "tab.name": tabName,
                "file_mtime": String(format: "%.3f", mtime.timeIntervalSince1970),
                "stale_age_seconds": String(format: "%.1f", staleAge),
            ])
        applyLatestPayload(reason: "freshness_recovery")
    }

    private func applyI1Enforcement(to data: inout StatusLineData) {
        guard let cwd = workingDirectory else { return }
        let wantedName = URL(filePath: cwd).lastPathComponent

        if let reported = data.worktree?.name, reported != wantedName {
            InvariantReporter.shared.violated(
                .statusLineWorktreeName,
                context: [
                    "pane.name": paneName, "pane.id": paneID.uuidString,
                    "tab.id": tabID.uuidString, "tab.name": tabName,
                    "field": "worktree.name",
                    "computed": wantedName,
                    "reported": reported,
                ])
        }
        if let reported = data.workspace?.gitWorktree, reported != cwd,
            URL(filePath: reported).lastPathComponent != wantedName
        {
            InvariantReporter.shared.violated(
                .statusLineWorktreeName,
                context: [
                    "pane.name": paneName, "pane.id": paneID.uuidString,
                    "tab.id": tabID.uuidString, "tab.name": tabName,
                    "field": "workspace.git_worktree",
                    "computed": wantedName,
                    "reported": reported,
                ])
        }
        data.worktree = StatusLineData.Worktree(name: wantedName, branch: data.worktree?.branch)
    }

    private func applyI3Enforcement(to data: inout StatusLineData) {
        let computedAdded = cachedGitStats.added
        let computedRemoved = cachedGitStats.removed

        if let reportedAdded = data.cost?.totalLinesAdded,
            let reportedRemoved = data.cost?.totalLinesRemoved,
            reportedAdded != computedAdded || reportedRemoved != computedRemoved
        {
            InvariantReporter.shared.violated(
                .statusLineLinesSource,
                context: [
                    "pane.name": paneName, "pane.id": paneID.uuidString,
                    "tab.id": tabID.uuidString, "tab.name": tabName,
                    "computed_added": "\(computedAdded)",
                    "reported_added": "\(reportedAdded)",
                    "computed_removed": "\(computedRemoved)",
                    "reported_removed": "\(reportedRemoved)",
                ])
        }
        data.cost = StatusLineData.Cost(
            totalCostUsd: data.cost?.totalCostUsd,
            totalDurationMs: data.cost?.totalDurationMs,
            totalLinesAdded: computedAdded,
            totalLinesRemoved: computedRemoved
        )
    }

    private func writeSettingsFile() {
        let prTrackingEnabled = SettingsPersistence.isPRTrackingEnabled()
        let settings = Self.makeClaudeSettingsDictionaryForTesting(
            statusOutputPath: filePath,
            attentionOutputPath: attentionSignalFilePath,
            activityOutputPath: activitySignalFilePath,
            hidePRStatus: prTrackingEnabled
        )
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted) else { return }
        try? data.write(to: URL(filePath: settingsFilePath))
        TracingService.shared.record(
            "statusline.settings_file.written",
            attributes: [
                "path": settingsFilePath,
                "bytes": String(data.count),
            ])
    }

    private func restartAttentionWatcherIfEligible() {
        stopAttentionWatcher()
        guard isClaude else { return }
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

    private func startActivityWatcher() {
        activitySource?.cancel()
        activitySource = nil
        let fd = open(activitySignalFilePath, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            guard let data = try? Data(contentsOf: URL(filePath: self.activitySignalFilePath)) else { return }
            Task { @MainActor in
                self.applyClaudeActivityPayload(data)
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        activitySource = src
    }

    private func applyClaudeActivityPayload(_ data: Data) {
        guard let payload = try? JSONDecoder().decode(ClaudeActivityPayload.self, from: data) else { return }
        let nextState: Bool
        switch payload.hookEventName {
        case "UserPromptSubmit":
            nextState = true
        case "Stop", "StopFailure":
            nextState = false
        default:
            return
        }
        guard nextState != isClaudeWorking else { return }
        isClaudeWorking = nextState
        TracingService.shared.record(
            "pane.activity.changed",
            attributes: [
                "pane.name": paneName, "pane.id": paneID.uuidString,
                "tab.id": tabID.uuidString, "tab.name": tabName,
                "state": nextState ? "working" : "idle",
                "source": "claude_hook",
                "hook_event": payload.hookEventName,
            ])
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
                guard let event = PaneAttentionEvent.claudeHook(data) else { return }
                TracingService.shared.record(
                    "statusline.attention.received",
                    attributes: [
                        "pane.name": self.paneName, "pane.id": self.paneID.uuidString,
                        "tab.id": self.tabID.uuidString, "tab.name": self.tabName,
                        "source": event.source.rawValue, "reason": event.reason,
                    ])
                self.onClaudeHookAttention?(event)
            }
        }
        attentionDebounceWork = work
        attentionDebounceLock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
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
        checkForMergedTransition(pr)
    }

    @MainActor
    private func checkForMergedTransition(_ pr: PullRequest?) {
        guard let pr else { return }
        let newState = pr.state.lowercased()
        if newState == "merged", lastKnownPRState != nil, lastKnownPRState != "merged" {
            TracingService.shared.record(
                "statusline.pr_transition",
                attributes: [
                    "pane.name": paneName, "pane.id": paneID.uuidString,
                    "tab.id": tabID.uuidString, "tab.name": tabName,
                    "old_state": lastKnownPRState ?? "nil",
                    "new_state": newState,
                ])
        }
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

    /// For testing only: directly invokes I1 enforcement on a mutable StatusLineData.
    @MainActor
    func testApplyI1Enforcement(to data: inout StatusLineData) {
        applyI1Enforcement(to: &data)
    }

    /// For testing only: directly invokes I3 enforcement on a mutable StatusLineData.
    @MainActor
    func testApplyI3Enforcement(to data: inout StatusLineData) {
        applyI3Enforcement(to: &data)
    }

    /// For testing only: injects cached git stats.
    @MainActor
    func testSetCachedGitStats(_ stats: (added: Int, removed: Int)) {
        cachedGitStats = stats
    }

    /// For testing only: invokes `applyLatestPayload` directly (reads from `filePath`).
    @MainActor
    func testApplyLatestPayload(reason: String) {
        applyLatestPayload(reason: reason)
    }

    /// For testing only: invokes `checkPayloadFreshness` directly.
    @MainActor
    func testCheckPayloadFreshness() {
        checkPayloadFreshness()
    }

    /// For testing only: applies Claude lifecycle hook stdin.
    @MainActor
    func testApplyClaudeActivityPayload(_ data: Data) {
        applyClaudeActivityPayload(data)
    }

    /// Builds the per-pane Claude `settings` dictionary (`statusLine` plus lifecycle and attention hooks) for tests and tooling.
    nonisolated static func makeClaudeSettingsDictionaryForTesting(
        statusOutputPath: String,
        attentionOutputPath: String,
        activityOutputPath: String,
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
            settings["prStatusFooterEnabled"] = false
        }
        let activityHook: [[String: Any]] = [["type": "command", "command": "cat > '\(activityOutputPath)'"]]
        let attentionHook: [[String: Any]] = [["type": "command", "command": "cat > '\(attentionOutputPath)'"]]
        settings["hooks"] = [
            "UserPromptSubmit": [["hooks": activityHook]],
            "Stop": [["hooks": activityHook]],
            "StopFailure": [["hooks": activityHook]],
            "PreToolUse": [["matcher": "AskUserQuestion|ExitPlanMode", "hooks": attentionHook]],
            "PermissionRequest": [["hooks": attentionHook]],
            "Notification": [["matcher": "permission_prompt|elicitation_dialog", "hooks": attentionHook]],
            "Elicitation": [["hooks": attentionHook]],
        ]
        return settings
    }
}

private struct ClaudeActivityPayload: Decodable {
    let hookEventName: String

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
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
