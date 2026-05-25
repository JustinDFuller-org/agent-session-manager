import XCTest

/// Tests session restoration across a full app restart. Intentionally does not extend
/// BaseTestCase and does not use `--uitesting-skip-restore` so that the restore path runs.
final class SessionPersistenceFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let sessionFile = UITestAppSupport.directory.appending(path: "sessions.json")
        try? FileManager.default.removeItem(at: sessionFile)

        let testDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "UITestWorkspace", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: testDir)
        GitUITestWorkspace.prepareCleanRepo()

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()
    }

    override func tearDown() {
        app.terminate()
        let sessionFile = UITestAppSupport.directory.appending(path: "sessions.json")
        try? FileManager.default.removeItem(at: sessionFile)
        super.tearDown()
    }

    func testSessionPersistenceFlow() {
        // Create a tab
        app.typeKey("t", modifierFlags: .command)
        let field = app.textFields["new-tab-name-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("PersistenceTab")
        app.buttons["new-tab-choose-dir-button"].click()
        let createBtn = app.buttons["new-tab-create-button"]
        XCTAssertTrue(createBtn.waitForExistence(timeout: 5))
        createBtn.click()
        XCTAssertTrue(app.buttons["tab-button-PersistenceTab"].waitForExistence(timeout: 5))

        let screenshotBefore = XCTAttachment(screenshot: app.screenshot())
        screenshotBefore.name = "13-before-quit"
        screenshotBefore.lifetime = .keepAlways
        add(screenshotBefore)

        // Quit and relaunch without clearing sessions — tab must be restored
        app.terminate()
        app.launch()

        let restoredTab = app.buttons["tab-button-PersistenceTab"]
        XCTAssertTrue(restoredTab.waitForExistence(timeout: 10))

        let screenshotAfter = XCTAttachment(screenshot: app.screenshot())
        screenshotAfter.name = "14-after-relaunch"
        screenshotAfter.lifetime = .keepAlways
        add(screenshotAfter)
    }
}
