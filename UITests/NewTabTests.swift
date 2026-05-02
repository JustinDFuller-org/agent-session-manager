import XCTest

final class NewTabTests: BaseTestCase {

    func testCreateTabViaButton() {
        app.buttons["new-tab-button"].click()

        let nameField = app.textFields["new-tab-name-field"]
        waitFor(nameField)
        screenshot("02-new-tab-sheet")

        nameField.click()
        nameField.typeText("MyTestTab")

        app.buttons["new-tab-choose-dir-button"].click()

        let createButton = app.buttons["new-tab-create-button"]
        waitFor(createButton)
        XCTAssertTrue(createButton.isEnabled)
        screenshot("03-new-tab-filled")

        createButton.click()

        let tabButton = app.buttons["tab-button-MyTestTab"]
        waitFor(tabButton)
        screenshot("04-tab-created")
        XCTAssertTrue(tabButton.exists)
    }

    func testCreateButtonDisabledWithEmptyName() {
        app.buttons["new-tab-button"].click()
        waitFor(app.textFields["new-tab-name-field"])
        // With no name and no directory, Create must be disabled
        XCTAssertFalse(app.buttons["new-tab-create-button"].isEnabled)
    }

    func testCancelDismissesSheet() {
        app.buttons["new-tab-button"].click()
        let nameField = app.textFields["new-tab-name-field"]
        waitFor(nameField)
        app.buttons["new-tab-cancel-button"].click()
        waitForDisappear(nameField)
    }

    func testCreateTabViaKeyboardShortcut() {
        app.typeKey("t", modifierFlags: .command)
        let nameField = app.textFields["new-tab-name-field"]
        waitFor(nameField)
        screenshot("05-new-tab-via-shortcut")
        XCTAssertTrue(nameField.exists)
    }
}
