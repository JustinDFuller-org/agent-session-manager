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
    /// Written by Codex lifecycle hooks to bind this pane to the exact Codex session.
    let codexHookRecordFilePath: String
    /// App-owned Codex hook script invoked by lifecycle hooks for this pane.
    let codexHookScriptFilePath: String
    private let workingDirectory: String?
    private let harness: Harness
    private let isClaude: Bool
    private let providerContext: StatusProviderContext?
    private var source: DispatchSourceFileSystemObject?
    private var attentionSource: DispatchSourceFileSystemObject?
    private var activitySource: DispatchSourceFileSystemObject?
    private let attentionDebounceLock = NSLock()
    private var attentionDebounceWork: DispatchWorkItem?
    private var lastAttentionPayloadFingerprint: Int?
    private var agnosticProvider: (any StatusLineDataProvider)?
    private var gitDiffTimer: Timer?
    private var cachedGitStats: (added: Int, removed: Int) = (0, 0)
    private var cachedRepoIdentity: StatusLineData.Repo?
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
        codexHookRecordFilePath =
            NSTemporaryDirectory() + "agent-session-manager-codex-session-\(paneID.uuidString).json"
        codexHookScriptFilePath =
            NSTemporaryDirectory() + "agent-session-manager-codex-hook-\(paneID.uuidString).py"
        let resolvedPaneName = self.paneName
        let resolvedCodexHookRecordPath = codexHookRecordFilePath
        providerContext = workingDirectory.map { cwd in
            StatusProviderContext(
                paneID: paneID,
                paneName: resolvedPaneName,
                tabID: tabID,
                tabName: tabName,
                workingDirectory: cwd,
                harness: harness,
                processStartTime: processStartTime,
                launchArgs: [],
                environment: [:],
                detectedHarnessVersion: nil,
                codexHookRecordPath: harness == .codex ? resolvedCodexHookRecordPath : nil
            )
        }

        if !isClaude, let cwd = workingDirectory {
            let provider: any StatusLineDataProvider
            if harness == .cursor {
                provider = CursorDataProvider(
                    workingDirectory: cwd, paneID: paneID, processStartTime: processStartTime)
            } else if harness == .codex, let providerContext {
                provider = CodexStatusProvider(context: providerContext)
            } else {
                let toolCmd = harness.commandDescription
                provider = ToolAgnosticDataProvider(
                    workingDirectory: cwd, toolCommand: toolCmd, processStartTime: processStartTime)
            }
            agnosticProvider = provider
            agnosticProvider?.onUpdate = { [weak self] data in
                guard let self else { return }
                self.applyProviderSnapshot(data, providerName: self.harness.rawValue)
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

    func supportsFact(_ item: StatusLineItem) -> Bool {
        item.supportedBy(harness)
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
            activitySource?.cancel()
            activitySource = nil
            let activityFD = open(activitySignalFilePath, O_EVTONLY)
            if activityFD >= 0 {
                let activityWatcher = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: activityFD,
                    eventMask: [.write, .extend],
                    queue: .global(qos: .utility)
                )
                activityWatcher.setEventHandler { [weak self] in
                    guard let self,
                        let data = try? Data(contentsOf: URL(filePath: self.activitySignalFilePath))
                    else { return }
                    Task { @MainActor in
                        self.applyClaudeActivityPayload(data)
                    }
                }
                activityWatcher.setCancelHandler { close(activityFD) }
                activityWatcher.resume()
                activitySource = activityWatcher
            }

            if let cwd = workingDirectory {
                Task { [weak self] in
                    guard let self else { return }
                    if let stats = await GitDiffStats.compute(in: cwd) {
                        await MainActor.run { self.cachedGitStats = stats }
                    }
                }
                startRepoIdentityFetch(cwd: cwd)
                gitDiffTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    Task { [weak self] in
                        guard let self else { return }
                        if let stats = await GitDiffStats.compute(in: cwd) {
                            await MainActor.run { self.cachedGitStats = stats }
                        }
                        await MainActor.run { self.checkPayloadFreshness() }
                    }
                }
            }

            stopAttentionWatcher()
            FileManager.default.createFile(atPath: attentionSignalFilePath, contents: nil)
            let attentionFD = open(attentionSignalFilePath, O_EVTONLY)
            if attentionFD >= 0 {
                let attentionWatcher = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: attentionFD,
                    eventMask: [.write, .extend],
                    queue: .global(qos: .utility)
                )
                attentionWatcher.setEventHandler { [weak self] in
                    guard let self else { return }
                    self.attentionDebounceLock.lock()
                    self.attentionDebounceWork?.cancel()
                    let work = DispatchWorkItem { [weak self] in
                        guard let self,
                            let data = try? Data(contentsOf: URL(filePath: self.attentionSignalFilePath)),
                            !data.isEmpty
                        else { return }
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
                    self.attentionDebounceWork = work
                    self.attentionDebounceLock.unlock()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
                }
                attentionWatcher.setCancelHandler { close(attentionFD) }
                attentionWatcher.resume()
                attentionSource = attentionWatcher
            }
        } else {
            TracingService.shared.record(
                "statusline.provider.started",
                attributes: providerTraceAttributes(providerName: harness.rawValue))
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
                    self.currentData = .empty(pr: pr)
                } else {
                    self.currentData?.pr = pr
                }
                self.checkForMergedTransition(pr)
            }
        }
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
        if !isClaude {
            TracingService.shared.record(
                "statusline.provider.stopped",
                attributes: providerTraceAttributes(providerName: harness.rawValue))
        }
        agnosticProvider = nil
        PRTrackingCoordinator.shared.unsubscribe(paneID: paneID)
        lastKnownPRState = nil
        hasFiredMergedNotification = false
        try? FileManager.default.removeItem(atPath: filePath)
        try? FileManager.default.removeItem(atPath: settingsFilePath)
        try? FileManager.default.removeItem(atPath: attentionSignalFilePath)
        try? FileManager.default.removeItem(atPath: activitySignalFilePath)
        try? FileManager.default.removeItem(atPath: codexHookRecordFilePath)
        try? FileManager.default.removeItem(atPath: codexHookScriptFilePath)
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
        enforced.repo = cachedRepoIdentity
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
            totalLinesRemoved: computedRemoved,
            totalApiDurationMs: data.cost?.totalApiDurationMs
        )
    }

    private func applyProviderSnapshot(_ data: StatusLineData, providerName: String) {
        var merged = data
        if let existing = currentData?.pr {
            merged.pr = existing
        }
        merged.repo = cachedRepoIdentity
        currentData = merged
        TracingService.shared.record(
            "statusline.provider.update_applied",
            attributes: providerTraceAttributes(providerName: providerName))
    }

    private func providerTraceAttributes(providerName: String) -> [String: String] {
        [
            "provider": providerName,
            "pane.name": paneName,
            "pane.id": paneID.uuidString,
            "tab.id": tabID.uuidString,
            "tab.name": tabName,
        ]
    }

    func writeSettingsFile() {
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
        guard !data.isEmpty else { return }
        guard let pr = try? JSONDecoder().decode(PullRequest.self, from: data) else { return }
        if currentData == nil {
            currentData = .empty(pr: pr)
        } else {
            currentData?.pr = pr
        }
        checkForMergedTransition(pr)
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

}

extension StatusLineMonitor {
    private func startRepoIdentityFetch(cwd: String) {
        Task { [weak self] in
            guard let self else { return }
            if let identity = await Self.fetchRepoIdentity(workingDirectory: cwd) {
                await MainActor.run { self.cachedRepoIdentity = identity }
            }
        }
    }

    static func fetchRepoIdentity(workingDirectory: String) async -> StatusLineData.Repo? {
        await withCheckedContinuation { continuation in
            let task = Process()
            let outPipe = Pipe()
            task.executableURL = URL(filePath: "/usr/bin/git")
            task.arguments = ["-C", workingDirectory, "remote", "get-url", "origin"]
            task.standardOutput = outPipe
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { _ in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                guard
                    let remote = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    !remote.isEmpty,
                    let identity = PRTrackingCoordinator.parseRepoIdentity(from: remote)
                else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: identity)
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
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

    /// For testing only: injects a cached repo identity directly.
    @MainActor
    func testSetCachedRepoIdentity(_ identity: StatusLineData.Repo?) {
        cachedRepoIdentity = identity
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

extension StatusLineMonitor {
    func writeCodexHookScript() {
        let script = """
            #!/usr/bin/env python3
            import json
            import os
            import sys
            import time

            payload = json.load(sys.stdin)
            record = {
                "pane_id": os.environ.get("AGENT_SESSION_MANAGER_PANE_ID", ""),
                "tab_id": os.environ.get("AGENT_SESSION_MANAGER_TAB_ID", ""),
                "session_id": payload.get("session_id", ""),
                "cwd": payload.get("cwd", ""),
                "model": payload.get("model"),
                "transcript_path": payload.get("transcript_path"),
                "hook_event_name": payload.get("hook_event_name", ""),
                "timestamp": time.time()
            }
            path = os.environ["AGENT_SESSION_MANAGER_CODEX_HOOK_RECORD_PATH"]
            tmp_path = path + ".tmp"
            with open(tmp_path, "w", encoding="utf-8") as handle:
                json.dump(record, handle, separators=(",", ":"))
            os.replace(tmp_path, path)
            """
        try? script.write(to: URL(filePath: codexHookScriptFilePath), atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: codexHookScriptFilePath)
        FileManager.default.createFile(atPath: codexHookRecordFilePath, contents: nil)
    }
}

private struct ClaudeActivityPayload: Decodable {
    let hookEventName: String

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
    }
}
