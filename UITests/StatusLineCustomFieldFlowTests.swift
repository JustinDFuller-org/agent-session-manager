import XCTest

final class StatusLineCustomFieldFlowTests: BaseTestCase {
    override func prepareTestWorkspace() {
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
        let iconSearchField = app.textFields["custom-statusline-icon-search-field"]
        waitFor(iconSearchField)
        iconSearchField.typeText("percent")
        let percentOption = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-icon-option-percent").firstMatch
        waitFor(percentOption)
        percentOption.click()
        waitForDisappear(iconSearchField)

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

    func testCustomFieldSelectorSearchExactSymbolAndHarnessSelectionPersist() {
        createTab(named: "CustomSelector")
        createPane(named: "custom-selector-pane")

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
        labelField.typeText("Selector")
        commandField.typeText("printf selector")

        let iconPicker = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-icon-picker").firstMatch
        let iconSearchField = app.textFields["custom-statusline-icon-search-field"]
        waitFor(iconPicker)
        iconPicker.click()
        waitFor(iconSearchField)
        iconSearchField.click()
        iconSearchField.typeText("usage")
        let percentOption = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-icon-option-percent").firstMatch
        waitFor(percentOption)
        percentOption.click()
        waitForDisappear(iconSearchField)
        XCTAssertEqual(iconPicker.value as? String, "percent")

        let exactSymbol = "heart.fill"
        iconPicker.click()
        waitFor(iconSearchField)
        iconSearchField.click()
        iconSearchField.typeText(exactSymbol)
        let useExactSymbolButton = app.buttons["custom-statusline-use-exact-symbol-button"]
        waitFor(useExactSymbolButton)
        XCTAssertEqual(useExactSymbolButton.value as? String, exactSymbol)
        useExactSymbolButton.click()
        waitForDisappear(iconSearchField)
        XCTAssertEqual(iconPicker.value as? String, exactSymbol)

        let unavailableSymbol = "not.a.real.sf.symbol"
        iconPicker.click()
        waitFor(iconSearchField)
        iconSearchField.click()
        iconSearchField.typeText(unavailableSymbol)
        let iconValidation = app.staticTexts["custom-statusline-icon-validation"]
        waitFor(iconValidation)
        XCTAssertTrue((iconValidation.value as? String)?.contains(unavailableSymbol) == true)
        XCTAssertFalse(useExactSymbolButton.exists)
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(iconSearchField)
        XCTAssertEqual(iconPicker.value as? String, exactSymbol)

        let harnessMenu = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-harness-menu").firstMatch
        waitFor(harnessMenu)
        XCTAssertEqual(harnessMenu.value as? String, "All harnesses")
        harnessMenu.click()

        let claudeHarness = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-harness-claude").firstMatch
        let cursorHarness = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-harness-cursor").firstMatch
        let codexHarness = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-harness-codex").firstMatch
        let openCodeHarness = app.descendants(matching: .any)
            .matching(identifier: "custom-statusline-harness-opencode").firstMatch
        waitFor(claudeHarness)
        claudeHarness.click()
        waitFor(cursorHarness)
        cursorHarness.click()
        waitFor(codexHarness)
        codexHarness.click()
        waitFor(openCodeHarness)
        XCTAssertFalse(openCodeHarness.isEnabled)

        settingsWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.02)).click()
        waitForDisappear(openCodeHarness)
        XCTAssertEqual(harnessMenu.value as? String, "OpenCode")

        harnessMenu.click()
        waitFor(openCodeHarness)
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(openCodeHarness)
        XCTAssertEqual(harnessMenu.value as? String, "OpenCode")

        let saveButton = app.buttons["custom-statusline-save-button"]
        waitFor(saveButton)
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.click()
        waitForDisappear(labelField)

        let editButton = settingsWindow.buttons.matching(
            NSPredicate(format: "label == 'Edit Selector'")
        ).firstMatch
        waitFor(editButton)
        editButton.click()
        waitFor(labelField)
        waitFor(iconPicker)
        waitFor(harnessMenu)
        XCTAssertEqual(iconPicker.value as? String, exactSymbol)
        XCTAssertEqual(harnessMenu.value as? String, "OpenCode")

        app.buttons["Cancel"].click()
        waitForDisappear(labelField)
    }
}
