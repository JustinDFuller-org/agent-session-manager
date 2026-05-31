import XCTest

extension XCTestCase {
    func screenshot(_ name: String, app: XCUIApplication) {
        let captured = app.windows.firstMatch.screenshot()
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
    func createTab(named name: String, directory: String = GitUITestWorkspace.directoryURL.path) {
        app.typeKey("t", modifierFlags: .command)
        let nameField = app.textFields["new-tab-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText(name)
        let dirField = app.textFields["new-tab-directory-field"]
        waitFor(dirField)
        dirField.click()
        dirField.typeText(directory)
        let createBtn = app.buttons["new-tab-create-button"]
        waitFor(createBtn)
        XCTAssertTrue(createBtn.isEnabled, "Create button should be enabled after typing directory")
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

    /// Waits for a pane's activity indicator to show the given state (idle/working/waiting).
    func waitForActivityState(_ state: String, paneName: String, timeout: TimeInterval = 120) {
        let id = "pane-activity-\(state)-\(paneName)"
        waitFor(app.descendants(matching: .any).matching(identifier: id).firstMatch, timeout: timeout)
    }
}
