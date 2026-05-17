import XCTest

@testable import AgentSessionManager

@MainActor
final class PRTrackingCoordinatorTests: XCTestCase {

    // MARK: - parseOwnerRepo

    func testParseOwnerRepoHTTPS() {
        let result = PRTrackingCoordinator.parseOwnerRepo(
            from: "https://github.com/JustinDFuller/agent-session-manager.git")
        XCTAssertEqual(result?.owner, "JustinDFuller")
        XCTAssertEqual(result?.repo, "agent-session-manager")
    }

    func testParseOwnerRepoHTTPSNoGitSuffix() {
        let result = PRTrackingCoordinator.parseOwnerRepo(from: "https://github.com/owner/repo")
        XCTAssertEqual(result?.owner, "owner")
        XCTAssertEqual(result?.repo, "repo")
    }

    func testParseOwnerRepoSSH() {
        let result = PRTrackingCoordinator.parseOwnerRepo(from: "git@github.com:owner/repo.git")
        XCTAssertEqual(result?.owner, "owner")
        XCTAssertEqual(result?.repo, "repo")
    }

    func testParseOwnerRepoSSHNoGitSuffix() {
        let result = PRTrackingCoordinator.parseOwnerRepo(from: "git@github.com:owner/repo")
        XCTAssertEqual(result?.owner, "owner")
        XCTAssertEqual(result?.repo, "repo")
    }

    func testParseOwnerRepoUnrecognizedFormat() {
        XCTAssertNil(PRTrackingCoordinator.parseOwnerRepo(from: "not-a-url"))
    }

    // MARK: - parsePRFromGraphQLNode

    func testParsePRBasicFields() {
        let node: [String: Any] = [
            "number": 42,
            "title": "My PR",
            "state": "OPEN",
            "url": "https://github.com/owner/repo/pull/42",
            "isDraft": false,
            "mergeable": "MERGEABLE",
        ]
        let pr = PRTrackingCoordinator.parsePRFromGraphQLNode(node)
        XCTAssertNotNil(pr)
        XCTAssertEqual(pr?.number, 42)
        XCTAssertEqual(pr?.title, "My PR")
        XCTAssertEqual(pr?.state, "open")
        XCTAssertEqual(pr?.url, "https://github.com/owner/repo/pull/42")
        XCTAssertEqual(pr?.isDraft, false)
        XCTAssertEqual(pr?.mergeable, "MERGEABLE")
    }

    func testParsePRStateIsLowercased() {
        let node: [String: Any] = ["number": 1, "title": "T", "state": "MERGED", "url": "u"]
        let pr = PRTrackingCoordinator.parsePRFromGraphQLNode(node)
        XCTAssertEqual(pr?.state, "merged")
    }

    func testParsePRStatusCheckRollupState() {
        let node: [String: Any] = [
            "number": 1,
            "title": "T",
            "state": "OPEN",
            "url": "u",
            "commits": [
                "nodes": [
                    [
                        "commit": [
                            "statusCheckRollup": ["state": "SUCCESS"]
                        ]
                    ]
                ]
            ],
        ]
        let pr = PRTrackingCoordinator.parsePRFromGraphQLNode(node)
        XCTAssertEqual(pr?.commitStatusState, "SUCCESS")
        XCTAssertEqual(pr?.buildStatus, .success)
    }

    func testParsePRReviewThreadCount() {
        let node: [String: Any] = [
            "number": 1,
            "title": "T",
            "state": "OPEN",
            "url": "u",
            "reviewThreads": ["totalCount": 3],
        ]
        let pr = PRTrackingCoordinator.parsePRFromGraphQLNode(node)
        XCTAssertEqual(pr?.unresolvedCommentCount, 3)
    }

    func testParsePRMissingRequiredFields() {
        let node: [String: Any] = ["number": 1, "title": "T"]
        XCTAssertNil(PRTrackingCoordinator.parsePRFromGraphQLNode(node))
    }

    func testParsePRConflictingMergeable() {
        let node: [String: Any] = [
            "number": 1, "title": "T", "state": "OPEN", "url": "u",
            "mergeable": "CONFLICTING",
        ]
        let pr = PRTrackingCoordinator.parsePRFromGraphQLNode(node)
        XCTAssertTrue(pr?.hasMergeConflicts ?? false)
    }

    // MARK: - buildBatchQuery

    func testBatchQueryBuildingSingleSubscriber() {
        let coordinator = PRTrackingCoordinator()
        let paneID = UUID()
        let alias = "pane_" + paneID.uuidString.replacingOccurrences(of: "-", with: "")
        coordinator.subscribers[paneID] = makeRecord(owner: "owner1", repo: "repo1", branch: "feature-1")
        let query = coordinator.buildBatchQuery()
        XCTAssertTrue(query.contains(alias), "Query should contain alias for pane")
        XCTAssertTrue(query.contains("owner1"), "Query should contain owner")
        XCTAssertTrue(query.contains("repo1"), "Query should contain repo")
        XCTAssertTrue(query.contains("feature-1"), "Query should contain branch")
        XCTAssertTrue(query.contains("statusCheckRollup"), "Query should request CI status")
        XCTAssertTrue(query.contains("reviewThreads"), "Query should request review threads")
    }

    func testBatchQueryBuildingMultipleSubscribers() {
        let coordinator = PRTrackingCoordinator()
        let pane1 = UUID()
        let pane2 = UUID()
        coordinator.subscribers[pane1] = makeRecord(owner: "owner1", repo: "repo1", branch: "branch-a")
        coordinator.subscribers[pane2] = makeRecord(owner: "owner2", repo: "repo2", branch: "branch-b")
        let query = coordinator.buildBatchQuery()
        let alias1 = "pane_" + pane1.uuidString.replacingOccurrences(of: "-", with: "")
        let alias2 = "pane_" + pane2.uuidString.replacingOccurrences(of: "-", with: "")
        XCTAssertTrue(query.contains(alias1))
        XCTAssertTrue(query.contains(alias2))
        XCTAssertTrue(query.contains("owner1"))
        XCTAssertTrue(query.contains("owner2"))
    }

    func testBatchQuerySkipsUnresolvedSubscribers() {
        let coordinator = PRTrackingCoordinator()
        let resolved = UUID()
        let unresolved = UUID()
        coordinator.subscribers[resolved] = makeRecord(owner: "owner", repo: "repo", branch: "main")
        coordinator.subscribers[unresolved] = makeRecord(owner: nil, repo: nil, branch: nil)
        let query = coordinator.buildBatchQuery()
        let resolvedAlias = "pane_" + resolved.uuidString.replacingOccurrences(of: "-", with: "")
        let unresolvedAlias = "pane_" + unresolved.uuidString.replacingOccurrences(of: "-", with: "")
        XCTAssertTrue(query.contains(resolvedAlias))
        XCTAssertFalse(query.contains(unresolvedAlias))
    }

    func testBatchQuerySkipsHEADBranch() {
        let coordinator = PRTrackingCoordinator()
        let paneID = UUID()
        coordinator.subscribers[paneID] = makeRecord(owner: "owner", repo: "repo", branch: "HEAD")
        let query = coordinator.buildBatchQuery()
        XCTAssertTrue(query.isEmpty, "Detached HEAD should be excluded from batch query")
    }

    func testBatchQueryEmptyWhenNoResolvedSubscribers() {
        let coordinator = PRTrackingCoordinator()
        let paneID = UUID()
        coordinator.subscribers[paneID] = makeRecord(owner: nil, repo: nil, branch: nil)
        let query = coordinator.buildBatchQuery()
        XCTAssertTrue(query.isEmpty)
    }

    // MARK: - adjustInterval

    func testAdjustIntervalBackoffOnLowRemaining() {
        let coordinator = PRTrackingCoordinator()
        coordinator.effectiveInterval = 30
        coordinator.adjustInterval(remainingPoints: 400)
        XCTAssertEqual(coordinator.effectiveInterval, 60, accuracy: 1)
    }

    func testAdjustIntervalDoublingCapsAt600() {
        let coordinator = PRTrackingCoordinator()
        coordinator.effectiveInterval = 400
        coordinator.adjustInterval(remainingPoints: 400)
        XCTAssertEqual(coordinator.effectiveInterval, 600, accuracy: 1)
    }

    func testAdjustIntervalRestoresOnHighRemaining() {
        let coordinator = PRTrackingCoordinator()
        coordinator.effectiveInterval = 120
        coordinator.adjustInterval(remainingPoints: 3000)
        XCTAssertLessThan(coordinator.effectiveInterval, 120)
    }

    func testAdjustIntervalNoChangeWhenHealthy() {
        let coordinator = PRTrackingCoordinator()
        coordinator.effectiveInterval = 30
        coordinator.adjustInterval(remainingPoints: 3000)
        XCTAssertEqual(coordinator.effectiveInterval, 30, accuracy: 1)
    }

    // MARK: - subscribe / unsubscribe

    func testSubscribeDeliversCachedDataImmediately() {
        let coordinator = PRTrackingCoordinator()
        let paneID = UUID()
        let cachedPR = PullRequest(number: 5, title: "Cached", state: "open", url: "u")
        coordinator.subscribers[paneID] = PRTrackingCoordinator.SubscriberRecord(
            workingDirectory: "/tmp",
            owner: "o",
            repo: "r",
            branchName: "main",
            lastData: cachedPR,
            callback: { _ in },
            isActive: true
        )

        var receivedPR: PullRequest?
        coordinator.subscribe(paneID: paneID, workingDirectory: "/tmp", isActive: true) { pr in
            receivedPR = pr
        }

        XCTAssertEqual(receivedPR?.number, 5)
    }

    func testUnsubscribeRemovesRecord() {
        let coordinator = PRTrackingCoordinator()
        let paneID = UUID()
        coordinator.subscribers[paneID] = makeRecord(owner: "o", repo: "r", branch: "main")
        coordinator.unsubscribe(paneID: paneID)
        XCTAssertNil(coordinator.subscribers[paneID])
    }

    func testSetActiveUpdatesRecord() {
        let coordinator = PRTrackingCoordinator()
        let paneID = UUID()
        coordinator.subscribers[paneID] = makeRecord(owner: "o", repo: "r", branch: "main")
        coordinator.setActive(paneID: paneID, isActive: false)
        XCTAssertEqual(coordinator.subscribers[paneID]?.isActive, false)
    }

    // MARK: - pause / resume

    func testPausePreservesSubscribers() {
        let coordinator = PRTrackingCoordinator()
        let paneID = UUID()
        coordinator.subscribers[paneID] = makeRecord(owner: "o", repo: "r", branch: "main")
        coordinator.pause()
        XCTAssertNotNil(coordinator.subscribers[paneID])
    }

    func testResumeWhileNotPausedReschedulesTimer() {
        let coordinator = PRTrackingCoordinator()
        XCTAssertFalse(coordinator.isPaused)
        coordinator.resume()
        XCTAssertFalse(coordinator.isPaused)
    }

    func testPauseWithBackgroundRefreshEnabledKeepsTimerRunning() {
        let tmpDir = makeTempSettingsDir(backgroundRefreshEnabled: true, backgroundIntervalSeconds: 60)
        defer { cleanupTempSettingsDir(tmpDir) }

        let coordinator = PRTrackingCoordinator()
        let paneID = UUID()
        coordinator.subscribers[paneID] = makeRecord(owner: "o", repo: "r", branch: "main")
        coordinator.pause()
        XCTAssertFalse(coordinator.isPaused)
        XCTAssertNotNil(coordinator.cycleTimer)
    }

    func testPauseWithBackgroundRefreshDisabledStopsTimer() {
        let tmpDir = makeTempSettingsDir(backgroundRefreshEnabled: false, backgroundIntervalSeconds: 60)
        defer { cleanupTempSettingsDir(tmpDir) }

        let coordinator = PRTrackingCoordinator()
        let paneID = UUID()
        coordinator.subscribers[paneID] = makeRecord(owner: "o", repo: "r", branch: "main")
        coordinator.pause()
        XCTAssertTrue(coordinator.isPaused)
        XCTAssertNil(coordinator.cycleTimer)
    }

    func testResumeFromBackgroundRefreshDisabledWithNoSubscribersLeavesTimerNil() {
        let tmpDir = makeTempSettingsDir(backgroundRefreshEnabled: false, backgroundIntervalSeconds: 60)
        defer { cleanupTempSettingsDir(tmpDir) }

        let coordinator = PRTrackingCoordinator()
        coordinator.pause()
        XCTAssertTrue(coordinator.isPaused)
        coordinator.resume()
        XCTAssertFalse(coordinator.isPaused)
        XCTAssertNil(coordinator.cycleTimer)
    }

    func testBackgroundedFlagSetOnPause() {
        let coordinator = PRTrackingCoordinator()
        XCTAssertFalse(coordinator.isBackgrounded)
        coordinator.pause()
        XCTAssertTrue(coordinator.isBackgrounded)
    }

    func testBackgroundedFlagClearedOnResume() {
        let coordinator = PRTrackingCoordinator()
        coordinator.pause()
        XCTAssertTrue(coordinator.isBackgrounded)
        coordinator.resume()
        XCTAssertFalse(coordinator.isBackgrounded)
    }

    func testResumeFromBackgroundRefreshRestoresForegroundInterval() {
        let tmpDir = makeTempSettingsDir(backgroundRefreshEnabled: true, backgroundIntervalSeconds: 90)
        defer { cleanupTempSettingsDir(tmpDir) }

        let coordinator = PRTrackingCoordinator()
        coordinator.pause()
        XCTAssertTrue(coordinator.isBackgrounded)
        coordinator.resume()
        XCTAssertFalse(coordinator.isBackgrounded)
    }

    // MARK: - Helpers

    private func makeRecord(owner: String?, repo: String?, branch: String?) -> PRTrackingCoordinator.SubscriberRecord {
        PRTrackingCoordinator.SubscriberRecord(
            workingDirectory: "/tmp",
            owner: owner,
            repo: repo,
            branchName: branch,
            lastData: nil,
            callback: { _ in },
            isActive: true
        )
    }

    /// Writes a temp pr-polling-settings.json inside ~/Library/Application Support/<subdirName>
    /// and redirects SettingsPersistence to read from that subdirectory.
    /// Returns the subdirectory name to pass to cleanupTempSettingsDir.
    @discardableResult
    private func makeTempSettingsDir(
        backgroundRefreshEnabled: Bool,
        backgroundIntervalSeconds: Int
    ) -> String {
        let subdirName = "pr-tests-\(UUID().uuidString)"
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appending(path: subdirName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let payload: [String: Any] = [
            "intervalSeconds": 30,
            "timeoutSeconds": 15,
            "backgroundRefreshEnabled": backgroundRefreshEnabled,
            "backgroundIntervalSeconds": backgroundIntervalSeconds,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: dir.appending(path: "pr-polling-settings.json"))
        }
        PersistenceHelpers.overrideAppSupportSubdirectory = subdirName
        return subdirName
    }

    private func cleanupTempSettingsDir(_ subdirName: String) {
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: appSupport.appending(path: subdirName))
    }
}
