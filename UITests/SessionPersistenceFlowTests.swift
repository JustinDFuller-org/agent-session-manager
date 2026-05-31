import XCTest

/// Tests session restoration across a full app restart. The restore path runs naturally
/// since no launch args skip it. Isolation comes from clearing the dev app-support dir.
final class SessionPersistenceFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let support = UITestAppSupport.directory
        try? FileManager.default.removeItem(at: support.appending(path: "sessions.json"))
        let onboardingJson = Data("{\"hasCompletedOnboarding\":true}".utf8)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? onboardingJson.write(to: support.appending(path: "onboarding-settings.json"))
        GitUITestWorkspace.prepareCleanRepo()

        app = XCUIApplication()
        app.launch()
        app.activate()
    }

    override func tearDown() {
        app.terminate()
        try? FileManager.default.removeItem(
            at: UITestAppSupport.directory.appending(path: "sessions.json"))
        super.tearDown()
    }

    func testSessionPersistenceFlow() {
        app.typeKey("t", modifierFlags: .command)
        let nameField = app.textFields["new-tab-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.click()
        nameField.typeText("PersistenceTab")
        let dirField = app.textFields["new-tab-directory-field"]
        XCTAssertTrue(dirField.waitForExistence(timeout: 5))
        dirField.click()
        dirField.typeText(GitUITestWorkspace.directoryURL.path)
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
