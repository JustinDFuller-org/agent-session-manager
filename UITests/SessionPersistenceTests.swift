import XCTest

final class SessionPersistenceTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Clear any prior sessions
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let sessionFile = support
            .appending(path: "agent-session-manager/sessions.json")
        try? FileManager.default.removeItem(at: sessionFile)

        let testDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "UITestWorkspace", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        // Always clear sessions after the persistence test so the next test starts clean.
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let sessionFile = support.appending(path: "agent-session-manager/sessions.json")
        try? FileManager.default.removeItem(at: sessionFile)
        super.tearDown()
    }

    func testTabsRestoredAfterRelaunch() {
        // Create a tab
        app.buttons["new-tab-button"].click()
        let field = app.textFields["new-tab-name-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("PersistenceTab")
        app.buttons["new-tab-choose-dir-button"].click()
        let createBtn = app.buttons["new-tab-create-button"]
        XCTAssertTrue(createBtn.waitForExistence(timeout: 5))
        createBtn.click()
        XCTAssertTrue(app.buttons["tab-button-PersistenceTab"].waitForExistence(timeout: 5))

        let screenshot1 = XCTAttachment(screenshot: app.screenshot())
        screenshot1.name = "13-before-quit"
        screenshot1.lifetime = .keepAlways
        add(screenshot1)

        // Quit and relaunch WITHOUT clearing sessions
        app.terminate()
        app.launch()

        let restoredTab = app.buttons["tab-button-PersistenceTab"]
        XCTAssertTrue(restoredTab.waitForExistence(timeout: 10))

        let screenshot2 = XCTAttachment(screenshot: app.screenshot())
        screenshot2.name = "14-after-relaunch"
        screenshot2.lifetime = .keepAlways
        add(screenshot2)
    }
}
