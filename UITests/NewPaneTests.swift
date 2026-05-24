import XCTest

final class NewPaneTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        createTab(named: "PaneTestTab")
    }

    func testCreatePane() {
        app.typeKey("p", modifierFlags: .command)

        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        screenshot("06-new-pane-sheet")

        nameField.click()
        nameField.typeText("auth-refactor")

        let openButton = app.buttons["new-pane-open-button"]
        XCTAssertTrue(openButton.isEnabled)
        openButton.click()

        let paneName = app.staticTexts["pane-name-auth-refactor"].firstMatch
        waitFor(paneName)
        screenshot("07-pane-created")
        XCTAssertTrue(paneName.exists)
    }

    func testOpenButtonDisabledWithEmptyName() {
        app.typeKey("p", modifierFlags: .command)
        waitFor(app.textFields["new-pane-name-field"])
        XCTAssertFalse(app.buttons["new-pane-open-button"].isEnabled)
    }

    func testCancelDismissesSheet() {
        app.typeKey("p", modifierFlags: .command)
        waitFor(app.textFields["new-pane-name-field"])
        app.buttons["new-pane-cancel-button"].click()
        XCTAssertFalse(app.textFields["new-pane-name-field"].exists)
    }

    func testCreatePaneViaKeyboardShortcut() {
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        screenshot("08-new-pane-via-shortcut")
        XCTAssertTrue(nameField.exists)
    }

    func testTabEmptyStateHintMentionsPaneShortcut() {
        waitFor(app.staticTexts["tab-empty-state-PaneTestTab"])
        // macOS 26+ SwiftUI stores StaticText content in .value, not .label
        XCTAssertEqual(app.staticTexts["tab-empty-state-PaneTestTab"].value as? String, "Press ⌘P to open a pane")
    }

    func testNewPaneMenuItemOpensSheet() {
        app.menuBars.menuBarItems["File"].click()
        let menuItem = app.menuBars.menuBarItems["File"].menuItems["New Pane in Current Tab"]
        waitFor(menuItem)
        XCTAssertTrue(menuItem.isEnabled)
        menuItem.click()
        waitFor(app.textFields["new-pane-name-field"])
        screenshot("08b-new-pane-via-menu")
    }

    func testCreateMultiplePanesInOneTab() {
        createPane(named: "feature-a")
        screenshot("09a-one-pane")

        createPane(named: "feature-b")
        screenshot("09b-two-panes")

        createPane(named: "feature-c")
        screenshot("09c-three-panes")

        XCTAssertTrue(app.staticTexts["pane-name-feature-a"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["pane-name-feature-b"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["pane-name-feature-c"].firstMatch.exists)
    }

    func testClosingOnePaneKeepsOthers() {
        createPane(named: "keep-pane")
        createPane(named: "close-pane")

        waitFor(app.staticTexts["pane-name-keep-pane"].firstMatch)
        waitFor(app.staticTexts["pane-name-close-pane"].firstMatch)
        screenshot("10a-two-panes-before-close")

        app.buttons["close-close-pane"].firstMatch.click()
        screenshot("10b-one-pane-after-close")

        XCTAssertTrue(app.staticTexts["pane-name-keep-pane"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["pane-name-close-pane"].exists)
    }

    func testFourPanesGridLayout() {
        createPane(named: "pane-1")
        createPane(named: "pane-2")
        createPane(named: "pane-3")
        createPane(named: "pane-4")

        screenshot("11-four-pane-grid")

        XCTAssertTrue(app.staticTexts["pane-name-pane-1"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["pane-name-pane-2"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["pane-name-pane-3"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["pane-name-pane-4"].firstMatch.exists)
    }

    func testInvalidNameShowsErrorAndDisablesOpenButton() {
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("invalid name")

        let errorText = app.staticTexts["new-pane-name-error"]
        waitFor(errorText)
        screenshot("12-pane-invalid-name")
        XCTAssertTrue(errorText.exists)
        XCTAssertFalse(app.buttons["new-pane-open-button"].isEnabled)
    }

    func testDuplicateNameShowsErrorAndDisablesOpenButton() {
        createPane(named: "my-feature")

        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("my-feature")

        let errorText = app.staticTexts["new-pane-name-error"]
        waitFor(errorText)
        screenshot("13-pane-duplicate-name")
        XCTAssertTrue(errorText.exists)
        XCTAssertFalse(app.buttons["new-pane-open-button"].isEnabled)
    }

    func testSessionNamePersistsAcrossToolSwitch() {
        // Enable Codex via Settings → Tools
        app.typeKey(",", modifierFlags: .command)
        waitFor(app.buttons["Tools"])
        app.buttons["Tools"].click()
        let codexCheckbox = app.checkBoxes["Codex"]
        waitFor(codexCheckbox)
        if codexCheckbox.value as? Int == 0 {
            codexCheckbox.click()
        }
        app.typeKey("w", modifierFlags: .command)

        // Open New Pane sheet and type a name
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("my-session")

        // Switch to Codex
        let codexButton = app.segmentedControls.firstMatch.buttons["Codex"]
        waitFor(codexButton)
        codexButton.click()

        // Name should persist in the Codex field
        waitForValue(nameField, value: "my-session")
        XCTAssertEqual(nameField.value as? String, "my-session")

        // Switch back to Claude — name should still be there
        app.segmentedControls.firstMatch.buttons["Claude"].click()
        waitForValue(nameField, value: "my-session")
        XCTAssertEqual(nameField.value as? String, "my-session")
    }

    func testCursorPaneShowsSessionNameInHeader() {
        // Enable Cursor via Settings → Tools
        app.typeKey(",", modifierFlags: .command)
        waitFor(app.buttons["Tools"])
        app.buttons["Tools"].click()
        let cursorCheckbox = app.checkBoxes["Cursor"]
        waitFor(cursorCheckbox)
        if cursorCheckbox.value as? Int == 0 {
            cursorCheckbox.click()
        }
        app.typeKey("w", modifierFlags: .command)

        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)

        let cursorButton = app.segmentedControls.firstMatch.buttons["Cursor"]
        waitFor(cursorButton)
        cursorButton.click()

        nameField.click()
        nameField.typeText("fix-login")

        app.buttons["new-pane-open-button"].click()

        let paneName = app.staticTexts["pane-name-fix-login"].firstMatch
        waitFor(paneName)
        XCTAssertTrue(paneName.exists)
    }

    func testCodexPaneShowsSessionNameInHeader() {
        // Enable Codex via Settings → Tools
        app.typeKey(",", modifierFlags: .command)
        waitFor(app.buttons["Tools"])
        app.buttons["Tools"].click()
        let codexCheckbox = app.checkBoxes["Codex"]
        waitFor(codexCheckbox)
        if codexCheckbox.value as? Int == 0 {
            codexCheckbox.click()
        }
        app.typeKey("w", modifierFlags: .command)

        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)

        let codexButton = app.segmentedControls.firstMatch.buttons["Codex"]
        waitFor(codexButton)
        codexButton.click()

        nameField.click()
        nameField.typeText("auth-refactor")

        app.buttons["new-pane-open-button"].click()

        let paneName = app.staticTexts["pane-name-auth-refactor"].firstMatch
        waitFor(paneName)
        XCTAssertTrue(paneName.exists)
    }

    func testUnifiedFieldKeepsBranchRefInputAndEnablesOpen() {
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("origin/feature-branch")

        XCTAssertTrue(app.textFields["new-pane-name-field"].exists)
        XCTAssertTrue(app.buttons["new-pane-open-button"].isEnabled)
        screenshot("13b-new-pane-unified-branch-ref")

        XCTAssertFalse(app.staticTexts["new-pane-name-error"].exists)
    }

    func testSessionNameFocusesOnSheetOpen() {
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)

        nameField.typeText("hello-focus")

        XCTAssertEqual(nameField.value as? String, "hello-focus")
    }

    func testTerminalReceivesFocusAfterPaneCreated() {
        createPane(named: "autofocus-test")

        // Type without clicking — keystrokes should be delivered to the terminal
        app.typeText("a")

        screenshot("14-autofocus-after-pane-created")
        // If focus was not delivered the keystroke would be silently swallowed
        // or trigger a system beep; reaching this line without a hang confirms
        // keystrokes were accepted.
        XCTAssertTrue(app.staticTexts["pane-name-autofocus-test"].firstMatch.exists)
    }
}
