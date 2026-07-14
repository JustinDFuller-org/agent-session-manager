import XCTest

final class CLIOptionPresetFlowTests: BaseTestCase {
    private let profileName = "Preset Test"

    private func openToolsTab() {
        app.typeKey(",", modifierFlags: .command)
        let toolsTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-tools").firstMatch
        waitFor(toolsTab)
        toolsTab.click()
    }

    private func definePresets(forFlagID flagID: String, presets: [String]) {
        let showToggle = app.checkBoxes["settings-cli-option-show-\(flagID)"]
        waitFor(showToggle)
        if showToggle.value as? Int == 0 {
            showToggle.click()
        }
        for preset in presets {
            let addButton = app.buttons["settings-cli-option-preset-add-\(flagID)"]
            waitFor(addButton)
            addButton.click()
            let fields = app.textFields.matching(identifier: "settings-cli-option-preset-value-\(flagID)")
            let field = fields.element(boundBy: fields.count - 1)
            waitFor(field)
            field.click()
            field.typeText(preset)
        }
    }

    private func enableOptionRow(flagLabel: String) {
        let toggle = app.checkBoxes.matching(NSPredicate(format: "label CONTAINS %@", flagLabel)).firstMatch
        waitFor(toggle)
        if toggle.value as? Int == 0 {
            toggle.click()
        }
    }

    private func valueMenu(forFlagID flagID: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "cli-option-value-menu-\(flagID)").firstMatch
    }

    private func toggleAllowMultipleSelections(forFlagID flagID: String) {
        let toggle = app.checkBoxes["settings-cli-option-allow-multi-\(flagID)"]
        waitFor(toggle)
        toggle.click()
    }

    /// Defines presets for --effort (single-select) and --mcp-config (multi-select), creates a
    /// profile that selects "high" and both mcp-config presets, marks both "Show on new pane",
    /// and saves it. Leaves Settings open on the Profiles tab.
    private func createPresetTestProfile() {
        openToolsTab()
        definePresets(forFlagID: "--mcp-config", presets: ["mcp-a", "mcp-b"])
        definePresets(forFlagID: "--effort", presets: ["low", "high"])

        let profilesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-profiles").firstMatch
        waitFor(profilesTab)
        profilesTab.click()

        let newProfileButton = app.buttons["New Profile"]
        waitFor(newProfileButton)
        newProfileButton.click()

        let nameField = app.textFields["profile-editor-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText(profileName)

        enableOptionRow(flagLabel: "--effort")
        let effortMenu = valueMenu(forFlagID: "--effort")
        waitFor(effortMenu)
        effortMenu.click()
        let highItem = app.menuItems["high"]
        waitFor(highItem)
        highItem.click()

        enableOptionRow(flagLabel: "--mcp-config")
        let mcpMenu = valueMenu(forFlagID: "--mcp-config")
        waitFor(mcpMenu)
        mcpMenu.click()
        let mcpAItem = app.menuItems["mcp-a"]
        waitFor(mcpAItem)
        mcpAItem.click()
        let mcpBItem = app.menuItems["mcp-b"]
        waitFor(mcpBItem, timeout: 2)
        mcpBItem.click()

        app.descendants(matching: .any).matching(identifier: "profile-editor-show-on-pane---effort").firstMatch
            .click()
        app.descendants(matching: .any).matching(identifier: "profile-editor-show-on-pane---mcp-config").firstMatch
            .click()

        let saveButton = app.buttons["Save"]
        waitFor(saveButton)
        saveButton.click()

        waitFor(app.staticTexts.matching(NSPredicate(format: "value == %@", profileName)).firstMatch)
    }

    func testProfileEditorSingleAndMultiSelectPresetPickers() {
        createPresetTestProfile()

        let effortMenu = valueMenu(forFlagID: "--effort")
        XCTAssertTrue(effortMenu.label.contains("high"), "Selecting a preset should update the single-select label")

        let mcpMenu = valueMenu(forFlagID: "--mcp-config")
        XCTAssertTrue(mcpMenu.label.contains("2 selected"), "Selecting two presets should summarize the count")
    }

    func testFlagWithoutPresetsStillShowsPlainTextFieldInProfileEditor() {
        openToolsTab()
        let profilesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-profiles").firstMatch
        waitFor(profilesTab)
        profilesTab.click()

        let newProfileButton = app.buttons["New Profile"]
        waitFor(newProfileButton)
        newProfileButton.click()

        let nameField = app.textFields["profile-editor-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("No Presets")

        enableOptionRow(flagLabel: "--model")
        let modelField = app.textFields["cli-option-value-field---model"]
        waitFor(modelField)
        XCTAssertFalse(
            valueMenu(forFlagID: "--model").exists,
            "--model has no presets and should not show a picker menu"
        )
        modelField.click()
        modelField.typeText("claude-opus-4-7")
        XCTAssertEqual(modelField.value as? String, "claude-opus-4-7")
    }

    func testNewPaneSheetPrefillsAndAllowsAdjustingPresetSelections() {
        createPresetTestProfile()
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        createTab(named: "PresetPane")
        app.typeKey("p", modifierFlags: .command)

        let profilePicker = app.descendants(matching: .any).matching(identifier: "new-pane-profile-picker").firstMatch
        waitFor(profilePicker)
        profilePicker.click()
        let presetTestItem = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", profileName)).firstMatch
        waitFor(presetTestItem)
        presetTestItem.click()

        let effortMenu = valueMenu(forFlagID: "--effort")
        waitFor(effortMenu)
        XCTAssertTrue(effortMenu.label.contains("high"), "New Pane sheet should pre-fill the saved effort selection")

        let mcpMenu = valueMenu(forFlagID: "--mcp-config")
        waitFor(mcpMenu)
        XCTAssertTrue(
            mcpMenu.label.contains("2 selected"), "New Pane sheet should pre-fill both saved mcp-config paths")

        mcpMenu.click()
        let mcpBItem = app.menuItems["mcp-b"]
        waitFor(mcpBItem)
        mcpBItem.click()
        XCTAssertTrue(mcpMenu.label.contains("mcp-a"), "Deselecting one preset should leave the other selected")

        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("preset-pane")
        app.buttons["new-pane-open-button"].click()
        waitForDisappear(nameField, timeout: 25)
        waitFor(app.staticTexts.matching(identifier: "pane-name-preset-pane").firstMatch, timeout: 10)
    }

    /// Toggling "Allow multiple selections" on a non-mcp-config flag should switch its picker from
    /// a single-select dropdown to the same checkbox-menu multi-select `--mcp-config` uses.
    func testTogglingAllowMultipleSelectionsSwitchesFlagToMultiSelectMenu() {
        openToolsTab()
        toggleAllowMultipleSelections(forFlagID: "--model")
        definePresets(forFlagID: "--model", presets: ["model-a", "model-b"])

        let profilesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-profiles").firstMatch
        waitFor(profilesTab)
        profilesTab.click()

        let newProfileButton = app.buttons["New Profile"]
        waitFor(newProfileButton)
        newProfileButton.click()

        let nameField = app.textFields["profile-editor-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("Multi Model Profile")

        enableOptionRow(flagLabel: "--model")
        XCTAssertFalse(
            app.textFields["cli-option-value-field---model"].exists,
            "--model should no longer render as a plain text field once multi-select is enabled"
        )

        let modelMenu = valueMenu(forFlagID: "--model")
        waitFor(modelMenu)
        modelMenu.click()
        let modelAItem = app.menuItems["model-a"]
        waitFor(modelAItem)
        modelAItem.click()
        let modelBItem = app.menuItems["model-b"]
        waitFor(modelBItem, timeout: 2)
        modelBItem.click()

        XCTAssertTrue(modelMenu.label.contains("2 selected"), "Selecting two presets should summarize the count")

        let saveButton = app.buttons["Save"]
        waitFor(saveButton)
        saveButton.click()
        waitFor(app.staticTexts.matching(NSPredicate(format: "value == %@", "Multi Model Profile")).firstMatch)

        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        createTab(named: "MultiModelPane")
        app.typeKey("p", modifierFlags: .command)

        let profilePicker = app.descendants(matching: .any).matching(identifier: "new-pane-profile-picker").firstMatch
        waitFor(profilePicker)
        profilePicker.click()
        let multiModelProfileItem = app.menuItems.matching(
            NSPredicate(format: "label CONTAINS %@", "Multi Model Profile")
        ).firstMatch
        waitFor(multiModelProfileItem)
        multiModelProfileItem.click()

        let newPaneModelMenu = valueMenu(forFlagID: "--model")
        waitFor(newPaneModelMenu)
        XCTAssertTrue(
            newPaneModelMenu.label.contains("2 selected"),
            "New Pane sheet should render the multi-select menu with both saved presets pre-filled"
        )
    }
}
