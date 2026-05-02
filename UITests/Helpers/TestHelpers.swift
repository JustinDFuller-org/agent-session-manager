import XCTest

extension BaseTestCase {
    func createTab(named name: String) {
        app.buttons["new-tab-button"].click()
        let field = app.textFields["new-tab-name-field"]
        waitFor(field)
        field.click()
        field.typeText(name)
        app.buttons["new-tab-choose-dir-button"].click()
        let createBtn = app.buttons["new-tab-create-button"]
        waitFor(createBtn)
        XCTAssertTrue(createBtn.isEnabled, "Create button should be enabled after choosing directory")
        createBtn.click()
        waitFor(app.buttons["tab-button-\(name)"].firstMatch)
    }

    func createPane(named name: String) {
        app.buttons["add-pane-button"].click()
        let field = app.textFields["new-pane-name-field"]
        waitFor(field)
        field.click()
        field.typeText(name)
        app.buttons["new-pane-open-button"].click()
        waitFor(app.groups["pane-header-\(name)"])
    }
}
