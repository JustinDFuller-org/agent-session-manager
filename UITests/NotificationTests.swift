import XCTest

final class NotificationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-skip-restore"]
        app.launch()
    }

    func testNotificationsTabVisibleInSettings() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        XCTAssertTrue(notificationsTab.waitForExistence(timeout: 3))
    }

    func testNotificationsSettingsControlsVisible() {
        app.typeKey(",", modifierFlags: .command)
        app.buttons["Notifications"].click()

        let sidebarSide = app.segmentedControls["settings-sidebar-side"]
        XCTAssertTrue(sidebarSide.waitForExistence(timeout: 3))

        let priorityToggle = app.checkBoxes["settings-priority-notifications-toggle"]
        XCTAssertTrue(priorityToggle.waitForExistence(timeout: 3))
    }

    func testPriorityToggleAppearsInNewPaneSheetWhenEnabled() throws {
        app.typeKey(",", modifierFlags: .command)
        app.buttons["Notifications"].click()

        let priorityToggle = app.checkBoxes["settings-priority-notifications-toggle"]
        XCTAssertTrue(priorityToggle.waitForExistence(timeout: 3))

        if priorityToggle.value as? Int == 0 {
            priorityToggle.click()
        }

        app.typeKey("w", modifierFlags: [.command, .shift])

        let window = app.windows.firstMatch
        window.typeKey("w", modifierFlags: .command)
        app.buttons["Notifications"].firstMatch.click()

        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows.element(boundBy: 1)
        settingsWindow.typeKey("w", modifierFlags: .command)

        createTabAndOpenNewPane()
        let newPanePriorityToggle = app.checkBoxes["new-pane-priority-toggle"]
        XCTAssertTrue(newPanePriorityToggle.waitForExistence(timeout: 3))
    }

    func testPriorityToggleHiddenInNewPaneSheetWhenDisabled() throws {
        app.typeKey(",", modifierFlags: .command)
        app.buttons["Notifications"].click()

        let priorityToggle = app.checkBoxes["settings-priority-notifications-toggle"]
        XCTAssertTrue(priorityToggle.waitForExistence(timeout: 3))
        if priorityToggle.value as? Int == 1 {
            priorityToggle.click()
        }

        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows.element(boundBy: 1)
        settingsWindow.typeKey("w", modifierFlags: .command)

        createTabAndOpenNewPane()
        let newPanePriorityToggle = app.checkBoxes["new-pane-priority-toggle"]
        XCTAssertFalse(newPanePriorityToggle.exists)
    }

    // MARK: - Helpers

    private func createTabAndOpenNewPane() {
        app.typeKey("t", modifierFlags: .command)
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        nameField.typeText("TestTab")
        app.typeKey(.return, modifierFlags: [])
        app.typeKey("p", modifierFlags: [.command, .shift])
    }
}
