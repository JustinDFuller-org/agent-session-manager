import XCTest

extension XCTestCase {
    func screenshot(_ name: String, app: XCUIApplication) {
        let captured = app.screenshot()
        let attachment = XCTAttachment(screenshot: captured)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let outputPath = ProcessInfo.processInfo.environment["SCREENSHOTS_OUTPUT_PATH"] {
            let dir = URL(fileURLWithPath: outputPath)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? captured.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }
}

extension BaseTestCase {
    func createTab(named name: String) {
        app.typeKey("t", modifierFlags: .command)
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
        app.typeKey("p", modifierFlags: .command)
        let field = app.textFields["new-pane-name-field"]
        waitFor(field)
        field.click()
        field.typeText(name)
        app.buttons["new-pane-open-button"].click()
        waitForDisappear(field, timeout: 25)
        // Wait for the pane name text — Text elements are reliably in the accessibility tree.
        waitFor(app.staticTexts.matching(identifier: "pane-name-\(name)").firstMatch, timeout: 10)
    }
}
