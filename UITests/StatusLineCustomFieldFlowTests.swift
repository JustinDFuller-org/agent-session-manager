import XCTest

final class StatusLineCustomFieldFlowTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        let file = UITestAppSupport.directory.appending(path: "default-branch.json")
        try? FileManager.default.removeItem(at: file)
    }

    override func tearDown() {
        let file = UITestAppSupport.directory.appending(path: "default-branch.json")
        try? FileManager.default.removeItem(at: file)
        super.tearDown()
    }

    func testSavedCustomFieldRunNowUpdatesRealPaneStatusLine() {
        createTab(named: "CustomStatus")
        createPane(named: "custom-pane")

        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["AgentSessionManager Settings"]
        waitFor(settingsWindow)
        let statusLineTab = settingsWindow.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-status-line").firstMatch
        waitFor(statusLineTab)
        statusLineTab.click()

        let addButton = settingsWindow.buttons["settings-statusline-add-custom-field-button"]
        waitFor(addButton)
        addButton.click()

        let labelField = app.textFields["custom-statusline-label-field"]
        let commandField = app.textViews["custom-statusline-command-field"]
        waitFor(labelField)
        waitFor(commandField)
        labelField.typeText("Live")
        commandField.typeText("printf live")

        let iconPicker = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-icon-picker").firstMatch
        waitFor(iconPicker)
        iconPicker.click()
        waitFor(app.menuItems["Percent"])
        app.menuItems["Percent"].click()

        let harnessMenu = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-harness-menu").firstMatch
        waitFor(harnessMenu)
        XCTAssertEqual(harnessMenu.label, "Harnesses")
        XCTAssertTrue((harnessMenu.value as? String)?.contains("All harnesses") == true)

        app.buttons["custom-statusline-save-button"].click()
        waitForDisappear(labelField)

        let addItem = settingsWindow.buttons.matching(NSPredicate(format: "label == 'Add Item'")).firstMatch
        waitFor(addItem)
        addItem.click()
        waitFor(app.menuItems["Live"])
        app.menuItems["Live"].click()

        let editButton = settingsWindow.buttons.matching(NSPredicate(format: "label == 'Edit Live'")).firstMatch
        waitFor(editButton)
        editButton.click()

        let runNowButton = app.buttons["custom-statusline-run-now-button"]
        waitFor(runNowButton)
        XCTAssertTrue(runNowButton.isEnabled)
        runNowButton.click()

        let startedMessage = app.staticTexts.matching(
            NSPredicate(format: "value CONTAINS 'Started in'")
        ).firstMatch
        waitFor(startedMessage)

        app.buttons["Cancel"].click()
        waitForDisappear(runNowButton)
        app.typeKey("w", modifierFlags: .command)

        let liveValue = app.staticTexts.matching(NSPredicate(format: "value == 'live'")).firstMatch
        waitFor(liveValue, timeout: 15)
    }
}
