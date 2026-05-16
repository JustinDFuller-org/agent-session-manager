import AppKit
import Foundation
import Observation

/// Batches all active pane PR lookups into a single GraphQL query per polling cycle,
/// replacing the N-calls-per-cycle REST approach with 1-call-per-cycle GraphQL.
@Observable
@MainActor
final class PRTrackingCoordinator {
    static let shared = PRTrackingCoordinator()

    struct SubscriberRecord {
        var workingDirectory: String
        var owner: String?
        var repo: String?
        var branchName: String?
        var lastData: PullRequest?
        var callback: (PullRequest?) -> Void
        var isActive: Bool
    }

    var subscribers: [UUID: SubscriberRecord] = [:]
    private(set) var cycleTimer: Timer?
    var effectiveInterval: TimeInterval = 30
    private var activeBatchProcess: Process?
    private var timeoutWorkItem: DispatchWorkItem?
    /// Incremented each time a new cycle starts; guards against stale async Tasks delivering results.
    private var cycleToken: UInt64 = 0
    private(set) var isPaused = false
    @ObservationIgnored nonisolated(unsafe) private var appStateObservers: [Any] = []

    init() {
        let center = NotificationCenter.default
        appStateObservers.append(
            center.addObserver(
                forName: NSApplication.willResignActiveNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.pause() }
            }
        )
        appStateObservers.append(
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.resume() }
            }
        )
    }

    deinit {
        for observer in appStateObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func subscribe(
        paneID: UUID,
        workingDirectory: String,
        isActive: Bool,
        onPRData: @escaping (PullRequest?) -> Void
    ) {
        var record = SubscriberRecord(
            workingDirectory: workingDirectory,
            callback: onPRData,
            isActive: isActive
        )
        if let cached = subscribers[paneID]?.lastData {
            record.lastData = cached
            onPRData(cached)
        }
        subscribers[paneID] = record
        resolveOwnerRepo(paneID: paneID, workingDirectory: workingDirectory)
        ensureCycleTimerRunning()
    }

    func unsubscribe(paneID: UUID) {
        subscribers.removeValue(forKey: paneID)
        if subscribers.isEmpty {
            stopAll()
        }
    }

    func setActive(paneID: UUID, isActive: Bool) {
        subscribers[paneID]?.isActive = isActive
    }

    private func ensureCycleTimerRunning() {
        guard !isPaused, cycleTimer == nil else { return }
        runCycle()
        scheduleCycleTimer()
    }

    func pause() {
        isPaused = true
        cycleTimer?.invalidate()
        cycleTimer = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        activeBatchProcess?.terminate()
        activeBatchProcess = nil
        DebugLogger.shared.log("[pr] coordinator paused (app backgrounded)")
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        guard !subscribers.isEmpty else { return }
        DebugLogger.shared.log("[pr] coordinator resumed (app foregrounded)")
        runCycle()
        scheduleCycleTimer()
    }

    private func scheduleCycleTimer() {
        cycleTimer?.invalidate()
        let settings = SettingsPersistence.prPollingSettings()
        effectiveInterval = max(15, TimeInterval(settings.intervalSeconds))
        cycleTimer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.subscribers.isEmpty else { return }
                self.runCycle()
                self.scheduleCycleTimer()
            }
        }
    }

    private func stopAll() {
        cycleTimer?.invalidate()
        cycleTimer = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        activeBatchProcess?.terminate()
        activeBatchProcess = nil
    }

    private func runCycle() {
        guard SettingsPersistence.isPRTrackingEnabled() else { return }

        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        activeBatchProcess?.terminate()
        activeBatchProcess = nil
        cycleToken += 1
        let token = cycleToken

        let paneIDs = subscribers.keys.filter {
            subscribers[$0]?.owner != nil && subscribers[$0]?.repo != nil
        }
        guard !paneIDs.isEmpty else {
            DebugLogger.shared.log("[pr] coordinator cycle skipped: no resolved subscribers")
            return
        }

        DebugLogger.shared.log("[pr] coordinator cycle starting for \(paneIDs.count) resolved subscriber(s)")

        Task { @MainActor [weak self] in
            guard let self, self.cycleToken == token else { return }

            await withTaskGroup(of: (UUID, String?).self) { group in
                for paneID in paneIDs {
                    guard let cwd = self.subscribers[paneID]?.workingDirectory else { continue }
                    group.addTask {
                        let branch = await Self.fetchBranch(workingDirectory: cwd)
                        return (paneID, branch)
                    }
                }
                for await (paneID, branch) in group {
                    self.subscribers[paneID]?.branchName = branch
                }
            }

            guard self.cycleToken == token else { return }
            self.runBatchQuery(token: token)
        }
    }

    private func runBatchQuery(token: UInt64) {
        guard SettingsPersistence.isPRTrackingEnabled() else { return }
        let query = buildBatchQuery()
        guard !query.isEmpty else {
            DebugLogger.shared.log("[pr] coordinator batch query empty: no subscribers with resolved branch")
            return
        }

        let settings = SettingsPersistence.prPollingSettings()
        let tempPath = NSTemporaryDirectory() + "agent-session-manager-graphql-\(UUID().uuidString).json"
        let jsonBody = ["query": query]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody),
            (try? jsonData.write(to: URL(filePath: tempPath))) != nil
        else {
            DebugLogger.shared.log("[pr] coordinator failed to write temp query file")
            return
        }

        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.executableURL = URL(filePath: "/bin/zsh")
        task.arguments = ["-c", "gh api graphql --include --input '\(tempPath)'"]
        task.standardOutput = outPipe
        task.standardError = errPipe

        let timeoutWork = DispatchWorkItem { [weak task] in
            task?.terminate()
            DebugLogger.shared.log("[pr] coordinator batch query timed out after \(settings.timeoutSeconds)s")
        }
        timeoutWorkItem = timeoutWork
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Double(settings.timeoutSeconds), execute: timeoutWork)

        task.terminationHandler = { [weak self] _ in
            timeoutWork.cancel()
            try? FileManager.default.removeItem(atPath: tempPath)
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor [weak self] in
                guard let self, self.cycleToken == token else { return }
                if !errData.isEmpty,
                    let errText = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    !errText.isEmpty
                {
                    DebugLogger.shared.log("[pr] coordinator batch graphql stderr: \(errText)")
                }
                self.activeBatchProcess = nil
                self.processBatchResponse(outData)
            }
        }

        activeBatchProcess = task
        do {
            try task.run()
            let count = subscribers.values.filter { $0.owner != nil && $0.repo != nil && $0.branchName != nil }.count
            DebugLogger.shared.log("[pr] coordinator batch graphql started with \(count) pane(s)")
        } catch {
            activeBatchProcess = nil
            try? FileManager.default.removeItem(atPath: tempPath)
            DebugLogger.shared.log("[pr] coordinator batch graphql failed to start: \(error)")
        }
    }

    func buildBatchQuery() -> String {
        var fragments: [String] = []
        for (paneID, record) in subscribers {
            guard let owner = record.owner,
                let repo = record.repo,
                let branch = record.branchName,
                !branch.isEmpty, branch != "HEAD"
            else { continue }
            let alias = "pane_" + paneID.uuidString.replacingOccurrences(of: "-", with: "")
            fragments.append(
                """
                \(alias): repository(owner: "\(owner)", name: "\(repo)") {
                  pullRequests(headRefName: "\(branch)", first: 1, states: [OPEN, MERGED, CLOSED]) {
                    nodes {
                      number title state url isDraft mergeable
                      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
                      reviewThreads(first: 1) { totalCount }
                    }
                  }
                }
                """
            )
        }
        guard !fragments.isEmpty else { return "" }
        return "query BatchedPRStatus { \(fragments.joined(separator: " ")) }"
    }

    private func processBatchResponse(_ data: Data) {
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

        let separators = ["\r\n\r\n", "\n\n"]
        var headerSection = ""
        var jsonText = text
        for sep in separators {
            let parts = text.components(separatedBy: sep)
            if parts.count >= 2 {
                headerSection = parts[0]
                jsonText = parts.dropFirst().joined(separator: sep)
                break
            }
        }

        var remainingPoints: Int?
        for line in headerSection.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            if lower.hasPrefix("x-ratelimit-remaining:") {
                let value = line.dropFirst("x-ratelimit-remaining:".count)
                    .trimmingCharacters(in: .whitespaces)
                remainingPoints = Int(value)
            }
        }

        if let points = remainingPoints {
            DebugLogger.shared.log("[pr] coordinator x-ratelimit-remaining=\(points)")
            adjustInterval(remainingPoints: points)
        }

        guard let jsonData = jsonText.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let dataDict = json["data"] as? [String: Any]
        else {
            DebugLogger.shared.log("[pr] coordinator batch response parse failed")
            return
        }

        for (paneID, _) in subscribers {
            let alias = "pane_" + paneID.uuidString.replacingOccurrences(of: "-", with: "")
            guard let repoData = dataDict[alias] as? [String: Any],
                let pullRequests = repoData["pullRequests"] as? [String: Any],
                let nodes = pullRequests["nodes"] as? [[String: Any]],
                let node = nodes.first
            else {
                subscribers[paneID]?.lastData = nil
                subscribers[paneID]?.callback(nil)
                continue
            }

            if let pr = Self.parsePRFromGraphQLNode(node) {
                DebugLogger.shared.log("[pr] coordinator pane \(paneID) pr=#\(pr.number) state=\(pr.state)")
                subscribers[paneID]?.lastData = pr
                subscribers[paneID]?.callback(pr)
            }
        }
    }

    func adjustInterval(remainingPoints: Int) {
        let settings = SettingsPersistence.prPollingSettings()
        let base = max(15, TimeInterval(settings.intervalSeconds))
        if remainingPoints < 500 {
            effectiveInterval = min(600, effectiveInterval * 2)
            DebugLogger.shared.log(
                "[pr] coordinator rate limit low (\(remainingPoints)), backing off to \(effectiveInterval)s")
        } else if remainingPoints > 2000, effectiveInterval > base {
            effectiveInterval = max(base, effectiveInterval / 1.5)
            DebugLogger.shared.log(
                "[pr] coordinator rate limit healthy (\(remainingPoints)), restoring to \(effectiveInterval)s")
        }
    }

    // MARK: - One-shot merged-PR check (used at startup)

    struct BranchInfo {
        var paneID: UUID
        var owner: String
        var repo: String
        var branch: String
    }

    /// Runs a single batched GraphQL query for the given branches and returns merged PR info.
    /// Does not require a running coordinator or active subscriptions.
    static func checkBranchesForMergedPRs(
        branches: [BranchInfo]
    ) async -> [(paneID: UUID, pr: PullRequest)] {
        guard !branches.isEmpty else { return [] }

        let query = buildStaticBatchQuery(branches: branches)
        guard !query.isEmpty else { return [] }

        guard let jsonText = await executeGraphQLQuery(query) else { return [] }
        return parseStaticBatchResponse(jsonText, branches: branches)
    }

    static func buildStaticBatchQuery(branches: [BranchInfo]) -> String {
        var fragments: [String] = []
        for info in branches {
            guard !info.branch.isEmpty, info.branch != "HEAD" else { continue }
            let alias = "pane_" + info.paneID.uuidString.replacingOccurrences(of: "-", with: "")
            fragments.append(
                """
                \(alias): repository(owner: "\(info.owner)", name: "\(info.repo)") {
                  pullRequests(headRefName: "\(info.branch)", first: 1, states: [OPEN, MERGED, CLOSED]) {
                    nodes {
                      number title state url isDraft mergeable
                      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
                      reviewThreads(first: 1) { totalCount }
                    }
                  }
                }
                """
            )
        }
        guard !fragments.isEmpty else { return "" }
        return "query BatchedPRStatus { \(fragments.joined(separator: " ")) }"
    }

    /// Executes a GraphQL query via `gh api graphql` and returns the JSON body (minus HTTP headers).
    nonisolated static func executeGraphQLQuery(_ query: String) async -> String? {
        let tempPath = NSTemporaryDirectory() + "agent-session-manager-graphql-\(UUID().uuidString).json"
        let jsonBody = ["query": query]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody),
            (try? jsonData.write(to: URL(filePath: tempPath))) != nil
        else { return nil }

        return await withCheckedContinuation { continuation in
            let task = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.executableURL = URL(filePath: "/bin/zsh")
            task.arguments = ["-c", "gh api graphql --include --input '\(tempPath)'"]
            task.standardOutput = outPipe
            task.standardError = errPipe
            task.terminationHandler = { _ in
                try? FileManager.default.removeItem(atPath: tempPath)
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                guard let text = String(data: outData, encoding: .utf8), !text.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let separators = ["\r\n\r\n", "\n\n"]
                var jsonText = text
                for sep in separators {
                    let parts = text.components(separatedBy: sep)
                    if parts.count >= 2 {
                        jsonText = parts.dropFirst().joined(separator: sep)
                        break
                    }
                }
                continuation.resume(returning: jsonText)
            }
            do {
                try task.run()
            } catch {
                try? FileManager.default.removeItem(atPath: tempPath)
                continuation.resume(returning: nil)
            }
        }
    }

    nonisolated static func parseStaticBatchResponse(
        _ jsonText: String,
        branches: [BranchInfo]
    ) -> [(paneID: UUID, pr: PullRequest)] {
        guard let jsonData = jsonText.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let dataDict = json["data"] as? [String: Any]
        else { return [] }

        var results: [(paneID: UUID, pr: PullRequest)] = []
        for info in branches {
            let alias = "pane_" + info.paneID.uuidString.replacingOccurrences(of: "-", with: "")
            guard let repoData = dataDict[alias] as? [String: Any],
                let pullRequests = repoData["pullRequests"] as? [String: Any],
                let nodes = pullRequests["nodes"] as? [[String: Any]],
                let node = nodes.first,
                let pr = parsePRFromGraphQLNode(node)
            else { continue }
            results.append((paneID: info.paneID, pr: pr))
        }
        return results
    }

    // MARK: - Git helpers

    private func resolveOwnerRepo(paneID: UUID, workingDirectory: String) {
        let task = Process()
        let outPipe = Pipe()
        task.executableURL = URL(filePath: "/usr/bin/git")
        task.arguments = ["-C", workingDirectory, "remote", "get-url", "origin"]
        task.standardOutput = outPipe
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { _ in
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            guard
                let raw = String(data: outData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
            else { return }
            if let (owner, repo) = Self.parseOwnerRepo(from: raw) {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.subscribers[paneID]?.owner = owner
                    self.subscribers[paneID]?.repo = repo
                    DebugLogger.shared.log("[pr] coordinator resolved owner=\(owner) repo=\(repo) for pane \(paneID)")
                }
            }
        }
        try? task.run()
    }

    static func fetchOwnerRepo(workingDirectory: String) async -> (owner: String, repo: String)? {
        await withCheckedContinuation { continuation in
            let task = Process()
            let outPipe = Pipe()
            task.executableURL = URL(filePath: "/usr/bin/git")
            task.arguments = ["-C", workingDirectory, "remote", "get-url", "origin"]
            task.standardOutput = outPipe
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { _ in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                guard
                    let raw = String(data: outData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
                else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: parseOwnerRepo(from: raw))
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    static func fetchBranch(workingDirectory: String) async -> String? {
        await withCheckedContinuation { continuation in
            let task = Process()
            let outPipe = Pipe()
            task.executableURL = URL(filePath: "/usr/bin/git")
            task.arguments = ["-C", workingDirectory, "rev-parse", "--abbrev-ref", "HEAD"]
            task.standardOutput = outPipe
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { _ in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let branch = String(data: outData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: (branch?.isEmpty == false && branch != "HEAD") ? branch : nil)
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Parsing helpers (internal for testing)

    nonisolated static func parseOwnerRepo(from remoteURL: String) -> (owner: String, repo: String)? {
        var cleaned = remoteURL
        if cleaned.hasSuffix(".git") { cleaned = String(cleaned.dropLast(4)) }

        if cleaned.hasPrefix("https://") || cleaned.hasPrefix("http://") {
            guard let url = URL(string: cleaned) else { return nil }
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count >= 2 else { return nil }
            return (parts[parts.count - 2], parts[parts.count - 1])
        }

        if cleaned.contains("@"), cleaned.contains(":") {
            let parts = cleaned.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            let pathParts = parts[1].split(separator: "/")
            guard pathParts.count >= 2 else { return nil }
            return (String(pathParts[pathParts.count - 2]), String(pathParts[pathParts.count - 1]))
        }

        return nil
    }

    nonisolated static func parsePRFromGraphQLNode(_ node: [String: Any]) -> PullRequest? {
        guard let number = node["number"] as? Int,
            let title = node["title"] as? String,
            let state = node["state"] as? String,
            let url = node["url"] as? String
        else { return nil }

        var pr = PullRequest(number: number, title: title, state: state.lowercased(), url: url)
        pr.isDraft = node["isDraft"] as? Bool
        pr.mergeable = node["mergeable"] as? String

        if let commits = node["commits"] as? [String: Any],
            let commitNodes = commits["nodes"] as? [[String: Any]],
            let firstCommit = commitNodes.first,
            let commit = firstCommit["commit"] as? [String: Any],
            let rollup = commit["statusCheckRollup"] as? [String: Any],
            let rollupState = rollup["state"] as? String
        {
            pr.commitStatusState = rollupState
        }

        if let reviewThreads = node["reviewThreads"] as? [String: Any],
            let totalCount = reviewThreads["totalCount"] as? Int
        {
            pr.unresolvedCommentCount = totalCount
        }

        return pr
    }
}
