import XCTest

final class TabPaneFlowTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        try? Data("\"head\"".utf8).write(to: UITestAppSupport.directory.appending(path: "worktree-base-ref.json"))
    }

    func testTabPaneFlow() {
        // Create first tab and assert initial state
        createTab(named: "WorkTab")
        waitFor(app.buttons["tab-button-WorkTab"].firstMatch)

        // File menu pane item enabled after tab created
        app.menuBars.menuBarItems["File"].click()
        let newPaneMenuItem = app.menuBars.menuBarItems["File"].menuItems["New Pane in Current Tab"]
        waitFor(newPaneMenuItem)
        XCTAssertTrue(newPaneMenuItem.isEnabled)
        newPaneMenuItem.click()
        waitFor(app.textFields["new-pane-name-field"])
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(app.textFields["new-pane-name-field"])

        // Loading dot absent on idle tab with no panes
        XCTAssertFalse(app.otherElements["tab-loading-dot-WorkTab"].firstMatch.exists)

        // Tab empty state hint mentions pane shortcut
        waitFor(app.staticTexts["tab-empty-state-WorkTab"])
        XCTAssertEqual(
            app.staticTexts["tab-empty-state-WorkTab"].value as? String,
            "Press ⌘P to open a pane"
        )

        // Open pane sheet: open button disabled when name is empty
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        XCTAssertFalse(app.buttons["new-pane-open-button"].isEnabled)

        // Priority toggle visible in pane sheet (default: priority notifications on)
        let newPanePriorityToggle = app.checkBoxes["new-pane-priority-toggle"]
        XCTAssertTrue(newPanePriorityToggle.waitForExistence(timeout: 3))

        // CLI picker exists (Claude Code is always active)
        let cliPicker = app.descendants(matching: .any).matching(identifier: "new-pane-cli-picker").firstMatch
        XCTAssertTrue(cliPicker.waitForExistence(timeout: 3))

        // Session name autofocus: field accepts typed text immediately
        nameField.typeText("my-session")
        XCTAssertEqual(nameField.value as? String, "my-session")

        // Invalid name shows error and disables open button
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("invalid name")
        let nameError = app.staticTexts["new-pane-name-error"]
        waitFor(nameError)
        XCTAssertFalse(app.buttons["new-pane-open-button"].isEnabled)

        // Branch-ref style input is valid (slash does not trigger error)
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("origin/feature-branch")
        XCTAssertFalse(app.staticTexts["new-pane-name-error"].exists)
        XCTAssertTrue(app.buttons["new-pane-open-button"].isEnabled)

        // Cancel dismisses sheet
        app.buttons["new-pane-cancel-button"].click()
        waitForDisappear(nameField)

        // Disable priority notifications, verify toggle disappears from pane sheet
        app.typeKey(",", modifierFlags: .command)
        waitFor(app.buttons["Notifications"])
        app.buttons["Notifications"].click()
        let priorityToggle2 = app.checkBoxes["settings-priority-notifications-toggle"]
        waitFor(priorityToggle2)
        if !priorityToggle2.isHittable {
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -200)
        }
        if priorityToggle2.value as? Int == 1 {
            priorityToggle2.click()
        }
        app.typeKey("w", modifierFlags: .command)

        app.typeKey("p", modifierFlags: .command)
        let paneField2 = app.textFields["new-pane-name-field"]
        waitFor(paneField2)
        XCTAssertFalse(app.checkBoxes["new-pane-priority-toggle"].exists)
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(paneField2)

        // Create "feature-a": header visible, terminal receives focus after creation
        createPane(named: "feature-a")
        waitFor(app.staticTexts["pane-name-feature-a"].firstMatch)
        XCTAssertFalse(app.otherElements["tab-loading-dot-WorkTab"].firstMatch.exists)
        app.typeText("a")
        XCTAssertTrue(app.staticTexts["pane-name-feature-a"].firstMatch.exists)

        // Duplicate name shows error and disables open button
        app.typeKey("p", modifierFlags: .command)
        let dupeField = app.textFields["new-pane-name-field"]
        waitFor(dupeField)
        dupeField.click()
        dupeField.typeText("feature-a")
        let dupeError = app.staticTexts["new-pane-name-error"]
        waitFor(dupeError)
        XCTAssertFalse(app.buttons["new-pane-open-button"].isEnabled)
        app.buttons["new-pane-cancel-button"].click()
        waitForDisappear(dupeField)

        // Create additional panes for layout tests
        createPane(named: "feature-b")
        XCTAssertTrue(app.staticTexts["pane-name-feature-a"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["pane-name-feature-b"].firstMatch.exists)

        createPane(named: "feature-c")
        createPane(named: "feature-d")
        XCTAssertTrue(app.staticTexts["pane-name-feature-c"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["pane-name-feature-d"].firstMatch.exists)
        screenshot("split-panes-four")

        // Close one pane: layout updates, remaining pane headers intact
        app.buttons.matching(identifier: "pane-close-feature-d").firstMatch.click()
        // Managed worktree panes show a cleanup alert — dismiss it to proceed.
        if app.windows.firstMatch.buttons["Keep Worktree"].waitForExistence(timeout: 3) {
            app.windows.firstMatch.buttons["Keep Worktree"].click()
        }
        waitForDisappear(app.staticTexts["pane-name-feature-d"].firstMatch, timeout: 10)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pane-header-feature-b").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pane-header-feature-c").firstMatch.exists)
        screenshot("pane-layout-after-close")

        // Close another pane via close button
        app.buttons.matching(identifier: "pane-close-feature-c").firstMatch.click()
        if app.windows.firstMatch.buttons["Keep Worktree"].waitForExistence(timeout: 3) {
            app.windows.firstMatch.buttons["Keep Worktree"].click()
        }
        waitForDisappear(app.staticTexts["pane-name-feature-c"].firstMatch, timeout: 10)
        XCTAssertTrue(app.staticTexts["pane-name-feature-a"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["pane-name-feature-b"].firstMatch.exists)

        // Create second tab and verify tab switching
        createTab(named: "BetaTab")
        XCTAssertTrue(app.buttons["tab-button-WorkTab"].firstMatch.exists)
        XCTAssertTrue(app.buttons["tab-button-BetaTab"].firstMatch.exists)

        // Click-switch back to WorkTab
        app.buttons["tab-button-WorkTab"].firstMatch.click()
        waitFor(app.staticTexts["pane-name-feature-a"].firstMatch)

        // ⌘1 keyboard shortcut: both tabs survive
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.buttons["tab-button-WorkTab"].firstMatch.exists)
        XCTAssertTrue(app.buttons["tab-button-BetaTab"].firstMatch.exists)

        // Close BetaTab via ⌘K while it is active
        app.buttons["tab-button-BetaTab"].firstMatch.click()
        app.typeKey("k", modifierFlags: .command)
        waitForDisappear(app.buttons["tab-button-BetaTab"].firstMatch)
        XCTAssertTrue(app.buttons["tab-button-WorkTab"].firstMatch.exists)

        // Close WorkTab via its tab close button → empty state restored
        app.buttons["tab-close-WorkTab"].firstMatch.click()
        waitForDisappear(app.buttons["tab-button-WorkTab"].firstMatch)
        waitFor(app.staticTexts["empty-state-hint"])
        screenshot("11-after-close-tab")
    }
}
