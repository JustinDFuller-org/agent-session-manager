import XCTest

class BaseTestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        clearPersistedState()
        GitUITestWorkspace.prepareCleanRepo()
        writeDefaultBranch("ui-root")
        writeOnboardingComplete()

        app = XCUIApplication()
        app.launch()
        app.activate()
    }

    override func tearDown() {
        if let failureCount = testRun?.failureCount, failureCount > 0 {
            let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            attachment.lifetime = .keepAlways
            attachment.name = "\(name)-failure"
            add(attachment)
        }
        app.terminate()
        // Clear state after termination so the next test always starts clean,
        // even if the app saved state during the test.
        clearPersistedState()
        super.tearDown()
    }

    func screenshot(_ name: String) {
        screenshot(name, app: app)
    }

    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Expected \(element.identifier) to exist within \(timeout)s"
        )
    }

    func waitForDisappear(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let pred = NSPredicate(format: "exists == false")
        let exp = XCTNSPredicateExpectation(predicate: pred, object: element)
        let result = XCTWaiter.wait(for: [exp], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected \(element.identifier) to disappear within \(timeout)s")
    }

    func waitForValue(_ element: XCUIElement, value: String, timeout: TimeInterval = 5) {
        let pred = NSPredicate { _, _ in element.value as? String == value }
        let exp = XCTNSPredicateExpectation(predicate: pred, object: nil)
        let result = XCTWaiter.wait(for: [exp], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected \(element.identifier) to have value '\(value)' within \(timeout)s")
    }

    var emptyStateHint: XCUIElement { app.staticTexts["empty-state-hint"] }

    func writeOnboardingComplete() {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let json = Data("{\"hasCompletedOnboarding\":true}".utf8)
        try? json.write(to: support.appending(path: "onboarding-settings.json"))
    }

    func writeDefaultBranch(_ branch: String) {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let json = "{\"isEnabled\":true,\"branchName\":\"\(branch)\"}"
        let data = Data(json.utf8)
        try? data.write(to: support.appending(path: "default-branch.json"))
    }

    func clearPersistedState() {
        let support = UITestAppSupport.directory
        for file in [
            "sessions.json", "settings.json", "codex-settings.json",
            "cursor-settings.json", "statusline-settings.json",
            "active-tools-settings.json", "default-branch.json",
            "notification-settings.json", "restart-settings.json",
            "worktree-cleanup.json", "existing-worktree-management.json",
            "debug-settings.json", "pr-tracking-settings.json",
            "tracing-settings.json", "pr-polling-settings.json",
            "terminal-settings.json", "worktree-base-ref.json", "exit-behavior.json",
            "env-var-settings.json", "profiles.json", "session-name-settings.json",
            "shell-settings.json", "onboarding-settings.json",
            "activity-indicator-settings.json",
        ] {
            try? FileManager.default.removeItem(at: support.appending(path: file))
        }
        try? FileManager.default.removeItem(at: support.appending(path: "traces"))
        try? FileManager.default.removeItem(at: support.appending(path: "invariants"))
    }

    /// Writes sessions.json with a single tab and pane pointing to `repoURL` on both directory
    /// and worktreeDirectory.  PRTrackingCoordinator resolves the remote + branch from `repoURL`
    /// and fires the startup merged-PR check against the real GitHub API.
    func writePRDetectionSession(repoURL: URL, paneName: String) {
        let repoPath = repoURL.path
        let tabID = UUID().uuidString
        let paneID = UUID().uuidString
        // swiftlint:disable:next line_length
        let json =
            "{\"tabs\":[{\"id\":\"\(tabID)\",\"name\":\"pr-demo\",\"directory\":\"\(repoPath)\",\"panes\":[{\"id\":\"\(paneID)\",\"name\":\"\(paneName)\",\"harness\":\"claude\",\"isPriority\":false,\"isMerged\":false,\"worktreeDirectory\":\"\(repoPath)\",\"worktreeIsManaged\":false,\"extraArgs\":[]}]}],\"activeTabIndex\":0,\"pendingNotifications\":[]}"
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? Data(json.utf8).write(to: support.appending(path: "sessions.json"))
    }

    /// Writes pr-polling-settings.json so the coordinator uses the minimum 15-second interval.
    func writePRPollingSettings(intervalSeconds: Int = 15) {
        // swiftlint:disable:next line_length
        let json =
            "{\"intervalSeconds\":\(intervalSeconds),\"timeoutSeconds\":15,\"backgroundRefreshEnabled\":true,\"backgroundIntervalSeconds\":60}"
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? Data(json.utf8).write(to: support.appending(path: "pr-polling-settings.json"))
    }
}
