import XCTest

class BaseTestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        clearPersistedState()
        GitUITestWorkspace.prepareCleanRepo()

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
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    func clearPersistedState() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        for file in ["sessions.json", "settings.json", "codex-settings.json",
                      "statusline-settings.json", "active-tools-settings.json",
                      "default-branch.json", "notification-settings.json"] {
            try? FileManager.default.removeItem(at: support.appending(path: file))
        }
    }
}
