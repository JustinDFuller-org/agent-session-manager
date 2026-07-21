import XCTest

class BaseTestCase: XCTestCase {
    var app: XCUIApplication!

    var additionalLaunchArguments: [String] { [] }
    var additionalLaunchEnvironment: [String: String] { [:] }

    /// Hook for suites that need to prepare real workspace state before the app launches.
    func prepareTestWorkspace() {}

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        clearPersistedState()
        GitUITestWorkspace.prepareCleanRepo()
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? Data("{\"isEnabled\":true,\"branchName\":\"ui-root\"}".utf8)
            .write(to: support.appending(path: "default-branch.json"))
        prepareTestWorkspace()

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-skip-restore"] + additionalLaunchArguments
        app.launchEnvironment = additionalLaunchEnvironment
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

    var emptyStateHint: XCUIElement { app.staticTexts["empty-state-hint"] }

    func clearPersistedState() {
        let support = UITestAppSupport.directory
        for file in [
            "sessions.json", "settings.json", "codex-settings.json",
            "cursor-settings.json", "opencode-settings.json", "opencode-env-var-settings.json",
            "statusline-settings.json",
            "active-tools-settings.json", "default-branch.json",
            "notification-settings.json", "restart-settings.json",
            "worktree-cleanup.json", "existing-worktree-management.json",
            "debug-settings.json", "pr-tracking-settings.json",
            "tracing-settings.json", "pr-polling-settings.json",
            "terminal-settings.json", "worktree-base-ref.json", "exit-behavior.json",
            "env-var-settings.json", "profiles.json", "session-name-settings.json",
            "shell-settings.json", "onboarding-settings.json",
            "activity-indicator-settings.json", "focus-mode-settings.json",
        ] {
            try? FileManager.default.removeItem(at: support.appending(path: file))
        }
        try? FileManager.default.removeItem(at: support.appending(path: "traces"))
        try? FileManager.default.removeItem(at: support.appending(path: "invariants"))
    }
}
