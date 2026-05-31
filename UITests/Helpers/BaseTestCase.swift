import XCTest

class BaseTestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        clearPersistedState()
        GitUITestWorkspace.prepareCleanRepo()
        writeDefaultBranch("ui-root")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-skip-restore"]
        app.launch()
        app.activate()
    }

    override func tearDown() {
        if let failureCount = testRun?.failureCount, failureCount > 0 {
            let attachment = XCTAttachment(screenshot: app.screenshot())
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
        ] {
            try? FileManager.default.removeItem(at: support.appending(path: file))
        }
        try? FileManager.default.removeItem(at: support.appending(path: "traces"))
        try? FileManager.default.removeItem(at: support.appending(path: "invariants"))
    }
}
