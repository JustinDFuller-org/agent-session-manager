import XCTest

class BaseTestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        clearPersistedSessions()
        createTestWorkspaceDirectory()

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDown() {
        if let failureCount = testRun?.failureCount, failureCount > 0 {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.lifetime = .keepAlways
            attachment.name = "\(name)-failure"
            add(attachment)
        }
        app.terminate()
        // Clear sessions after termination so the next test always starts clean,
        // even if the app saved state during the test.
        clearPersistedSessions()
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

    var emptyStateHint: XCUIElement { app.staticTexts["empty-state-hint"] }

    func clearPersistedSessions() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let sessionFile = support
            .appending(path: "agent-session-manager/sessions.json")
        try? FileManager.default.removeItem(at: sessionFile)
    }

    private func createTestWorkspaceDirectory() {
        let testDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "UITestWorkspace", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }
}
