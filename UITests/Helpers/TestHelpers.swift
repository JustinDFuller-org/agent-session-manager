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

    func openShellHere(from paneName: String) -> String {
        let sourceHeader = app.descendants(matching: .any)
            .matching(identifier: "pane-header-\(paneName)").firstMatch
        waitFor(sourceHeader)

        let baseName = "shell:\(paneName)"
        var shellName = baseName
        var suffix = 2
        while app.staticTexts["pane-name-\(shellName)"].exists {
            shellName = "\(baseName)-\(suffix)"
            suffix += 1
        }

        sourceHeader.rightClick()
        let menuItem = app.windows.firstMatch.menuItems["Open Shell Here"]
        waitFor(menuItem)
        menuItem.click()
        waitFor(app.staticTexts["pane-name-\(shellName)"].firstMatch, timeout: 10)
        return shellName
    }

    func typeTerminalCommand(_ command: String) {
        app.typeText(command)
        app.typeKey(.enter, modifierFlags: [])
    }
}
