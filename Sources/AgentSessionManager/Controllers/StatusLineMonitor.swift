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
        lastKnownPRState = nil
        hasFiredMergedNotification = false
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
            "cd '\(workingDirectory)' && branch=$(git branch --show-current 2>/dev/null) && [ -n \"$branch\" ] && gh pr view \"$branch\" --json number,title,state,url,isDraft,commits,statusCheckRollup,mergeable 2>/dev/null || true",
        ]
        task.standardOutput = outPipe
        task.standardError = errPipe

        task.terminationHandler = { _ in
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor [weak self] in
                guard let self, token == self.prQueryToken else { return }
                self.applyPROutputIfValid(outData)
                if let pr = self.currentData?.pr, let cwd = self.workingDirectory {
                    self.fetchBuildStatus(for: pr, workingDirectory: cwd, outData: outData)
                    self.fetchUnresolvedComments(for: pr, workingDirectory: cwd)
                }
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
    private func fetchBuildStatus(for pr: PullRequest, workingDirectory: String, outData: Data) {
        guard let (owner, repo) = extractOwnerRepo(workingDirectory: workingDirectory) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: outData) as? [String: Any],
            let commits = json["commits"] as? [[String: Any]],
            let headSHA = commits.first?["oid"] as? String
        else { return }

        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.executableURL = URL(filePath: "/bin/zsh")
        task.arguments = [
            "-c",
            "cd '\(workingDirectory)' && gh api 'repos/\(owner)/\(repo)/commits/\(headSHA)/status' --jq '.state' 2>/dev/null || true",
        ]
        task.standardOutput = outPipe
        task.standardError = errPipe

        task.terminationHandler = { _ in
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let state = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !state.isEmpty
                {
                    self.currentData?.pr?.commitStatusState = state
                }
            }
        }

        do {
            try task.run()
        } catch {
            return
        }
    }

    @MainActor
    private func fetchUnresolvedComments(for pr: PullRequest, workingDirectory: String) {
        guard let (owner, repo) = extractOwnerRepo(workingDirectory: workingDirectory) else { return }

        let query =
            "query($owner: String!, $repo: String!, $pr: Int!) { repository(owner: $owner, name: $repo) { pullRequest(number: $pr) { reviewThreads(first: 100) { totalCount } } } }"

        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.executableURL = URL(filePath: "/bin/zsh")
        task.arguments = [
            "-c",
            "cd '\(workingDirectory)' && gh api graphql -f owner='\(owner)' -f repo='\(repo)' -f pr=\(pr.number) -f query='\(query)' 2>/dev/null || true",
        ]
        task.standardOutput = outPipe
        task.standardError = errPipe

        task.terminationHandler = { _ in
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor [weak self] in
                guard let self, !outData.isEmpty else { return }
                guard let json = try? JSONSerialization.jsonObject(with: outData) as? [String: Any],
                    let data = json["data"] as? [String: Any],
                    let repository = data["repository"] as? [String: Any],
                    let pullRequest = repository["pullRequest"] as? [String: Any],
                    let threads = pullRequest["reviewThreads"] as? [String: Any],
                    let total = threads["totalCount"] as? Int
                else { return }
                self.currentData?.pr?.unresolvedCommentCount = total
            }
        }

        do {
            try task.run()
        } catch {
            return
        }
    }

    private func extractOwnerRepo(workingDirectory: String) -> (owner: String, repo: String)? {
        let task = Process()
        let outPipe = Pipe()
        task.executableURL = URL(filePath: "/usr/bin/git")
        task.arguments = ["-C", workingDirectory, "remote", "get-url", "origin"]
        task.standardOutput = outPipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        guard task.terminationStatus == 0 else { return nil }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else { return nil }

        var cleaned = raw
        if cleaned.hasSuffix(".git") {
            cleaned = String(cleaned.dropLast(4))
        }

        if cleaned.hasPrefix("https://") || cleaned.hasPrefix("http://") {
            guard let url = URL(string: cleaned) else { return nil }
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count >= 2 else { return nil }
            let owner = parts[parts.count - 2]
            let repo = parts[parts.count - 1]
            return (owner, repo)
        }

        if cleaned.contains("@") && cleaned.contains(":") {
            let parts = cleaned.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            let path = parts[1]
            let pathParts = path.split(separator: "/")
            guard pathParts.count >= 2 else { return nil }
            let owner = String(pathParts[pathParts.count - 2])
            let repo = String(pathParts[pathParts.count - 1])
            return (owner, repo)
        }

        return nil
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
                sessionStatus: nil, openCodeMode: nil,
                pr: pr
            )
        } else {
            currentData?.pr = pr
        }
        checkForMergedTransition(pr)
    }

    @MainActor
    private func checkForMergedTransition(_ pr: PullRequest) {
        let newState = pr.state.lowercased()
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
