import XCTest

final class TabPaneFlowTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        try? Data("\"head\"".utf8).write(to: UITestAppSupport.directory.appending(path: "worktree-base-ref.json"))
    }

    func testPaneStatusDotFlow() {
        createTab(named: "StatusTab")
        createPane(named: "running-pane")

        // Circle shapes don't appear under otherElements — search all descendants.
        let runningDot = app.descendants(matching: .any).matching(identifier: "pane-activity-idle-running-pane")
            .firstMatch
        XCTAssertTrue(runningDot.waitForExistence(timeout: 15))
    }

    func testPaneScrollbackOverrideFromCreationAndContextMenu() {
        createTab(named: "HistoryTab")
        app.typeKey("p", modifierFlags: .command)

        let nameField = app.textFields["new-pane-name-field"]
        let picker = app.descendants(matching: .any)
            .matching(identifier: "new-pane-scrollback-mode-picker").firstMatch
        waitFor(nameField)
        waitFor(picker)
        XCTAssertTrue((picker.value as? String)?.contains("Use Global Default") == true)

        picker.click()
        let unlimited = app.menuItems["Unlimited (50,000-line cap)"]
        waitFor(unlimited)
        unlimited.click()

        nameField.click()
        nameField.typeText("history-pane")
        app.buttons["new-pane-open-button"].click()

        let header = app.descendants(matching: .any)
            .matching(identifier: "pane-header-history-pane").firstMatch
        waitFor(header, timeout: 15)
        header.rightClick()
        let historyMenu = app.windows.firstMatch.menuItems["Scrollback History"]
        waitFor(historyMenu)
        historyMenu.hover()
        let useGlobal = app.descendants(matching: .any)
            .matching(identifier: "pane-scrollback-use-global").firstMatch
        waitFor(useGlobal)
        useGlobal.click()

        let warning = app.alerts["Reduce Scrollback History?"]
        waitFor(warning)
        warning.buttons["Reduce History"].click()
        waitForDisappear(warning)

        header.rightClick()
        let historyMenuAfterReset = app.windows.firstMatch.menuItems["Scrollback History"]
        waitFor(historyMenuAfterReset)
        historyMenuAfterReset.hover()
        let custom = app.menuItems["Custom\u{2026}"]
        waitFor(custom)
        custom.click()

        let paneField = app.textFields["pane-scrollback-lines-field"]
        waitFor(paneField)
        XCTAssertEqual(paneField.value as? String, "5000")
        paneField.click()
        paneField.typeKey("a", modifierFlags: .command)
        paneField.typeText("2000")
        app.buttons["Apply"].click()

        let customWarning = app.alerts["Reduce Scrollback History?"]
        waitFor(customWarning)
        customWarning.buttons["Reduce History"].click()
        waitForDisappear(customWarning)

        header.rightClick()
        let historyMenuAfterCustom = app.windows.firstMatch.menuItems["Scrollback History"]
        waitFor(historyMenuAfterCustom)
        historyMenuAfterCustom.hover()
        waitFor(app.menuItems["Custom\u{2026}"])
        app.menuItems["Custom\u{2026}"].click()
        let persistedPaneField = app.textFields["pane-scrollback-lines-field"]
        waitFor(persistedPaneField)
        XCTAssertEqual(persistedPaneField.value as? String, "2000")
        app.buttons["Cancel"].click()
        waitForDisappear(persistedPaneField)

        header.rightClick()
        let refresh = app.windows.firstMatch.menuItems["Refresh Pane\u{2026}"]
        waitFor(refresh)
        refresh.click()
        let refreshedField = app.textFields["new-pane-scrollback-lines-field"]
        waitFor(refreshedField)
        XCTAssertEqual(refreshedField.value as? String, "2000")
    }

    func testFocusPaneFlow() {
        createTab(named: "FocusTab")
        createPane(named: "reader")
        createPane(named: "worker")

        let readerHeader = app.descendants(matching: .any).matching(identifier: "pane-header-reader").firstMatch
        let workerName = app.staticTexts["pane-name-worker"].firstMatch
        let sidebar = app.descendants(matching: .any).matching(identifier: "notification-sidebar").firstMatch
        waitFor(readerHeader)
        waitFor(workerName)
        waitFor(sidebar)

        readerHeader.doubleClick()

        let showAll = app.buttons["pane-show-all-reader"].firstMatch
        waitFor(showAll)
        XCTAssertTrue(app.buttons["tab-button-FocusTab"].firstMatch.exists)
        waitForDisappear(workerName)
        waitForDisappear(sidebar)

        showAll.click()
        waitFor(workerName)
        waitFor(sidebar)

        let workerHeader = app.descendants(matching: .any).matching(identifier: "pane-header-worker").firstMatch
        waitFor(workerHeader)
        workerHeader.rightClick()
        let focusMenuItem = app.menuItems["Focus This Pane"]
        waitFor(focusMenuItem)
        focusMenuItem.click()

        waitFor(app.buttons["pane-show-all-worker"].firstMatch)
        waitForDisappear(app.staticTexts["pane-name-reader"].firstMatch)
    }

    func testNewPaneOptionListsRemainScrollableAndActionsReachable() {
        createTab(named: "OptionsTab")
        app.typeKey("p", modifierFlags: .command)

        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)

        let showCLIOptions = app.buttons["new-pane-show-hidden-options-button"]
        waitFor(showCLIOptions)
        showCLIOptions.click()

        let cliOptionsScrollView = app.scrollViews["new-pane-hidden-cli-options-scroll-view"]
        waitFor(cliOptionsScrollView)
        XCTAssertLessThanOrEqual(cliOptionsScrollView.frame.height, 160)

        let verboseToggle = app.checkBoxes.matching(NSPredicate(format: "label CONTAINS '--verbose'")).firstMatch
        waitFor(verboseToggle)
        cliOptionsScrollView.swipeUp()
        cliOptionsScrollView.swipeUp()
        XCTAssertTrue(verboseToggle.isHittable, "The lower CLI options should be reachable by scrolling")
        XCTAssertTrue(showCLIOptions.isHittable)
        XCTAssertEqual(showCLIOptions.label, "Fewer options")

        showCLIOptions.click()

        let showEnvVars = app.buttons["new-pane-show-hidden-env-vars-button"]
        waitFor(showEnvVars)
        showEnvVars.click()

        let envVarsScrollView = app.scrollViews["new-pane-hidden-env-vars-scroll-view"]
        waitFor(envVarsScrollView)
        XCTAssertLessThanOrEqual(envVarsScrollView.frame.height, 120)

        let debugVariable = app.checkBoxes.matching(NSPredicate(format: "label CONTAINS 'DEBUG'")).firstMatch
        waitFor(debugVariable)
        envVarsScrollView.swipeUp()
        envVarsScrollView.swipeUp()
        XCTAssertTrue(debugVariable.exists, "The environment-variable catalog should remain available while scrolling")
        XCTAssertTrue(showEnvVars.isHittable)
        XCTAssertEqual(showEnvVars.label, "Fewer options")
        XCTAssertTrue(app.buttons["new-pane-cancel-button"].isHittable)
    }

    func testOpenShellHereNamesShellPaneAfterSourcePane() {
        createTab(named: "ShellTab")
        createPane(named: "reader")

        let readerHeader = app.descendants(matching: .any).matching(identifier: "pane-header-reader").firstMatch
        waitFor(readerHeader)
        readerHeader.rightClick()

        let openShellHere = app.windows.firstMatch.menuItems["Open Shell Here"]
        waitFor(openShellHere)
        openShellHere.click()

        let shellPane = app.staticTexts["pane-name-shell:reader"].firstMatch
        waitFor(shellPane, timeout: 10)

        readerHeader.rightClick()
        let openShellHereAgain = app.windows.firstMatch.menuItems["Open Shell Here"]
        waitFor(openShellHereAgain)
        openShellHereAgain.click()

        let secondShellPane = app.staticTexts["pane-name-shell:reader-2"].firstMatch
        waitFor(secondShellPane, timeout: 10)
    }

    func testPaneContextMenuOffersCopyAndPaste() {
        createTab(named: "ClipboardTab")
        createPane(named: "reader")

        let readerHeader = app.descendants(matching: .any).matching(identifier: "pane-header-reader").firstMatch
        waitFor(readerHeader)
        readerHeader.rightClick()

        let copyItem = app.windows.firstMatch.menuItems["Copy"]
        let pasteItem = app.windows.firstMatch.menuItems["Paste"]
        waitFor(copyItem)
        waitFor(pasteItem)
        XCTAssertFalse(copyItem.isEnabled, "Copy should be disabled without an active selection")
        XCTAssertTrue(pasteItem.isEnabled)
        app.typeKey(.escape, modifierFlags: [])

        let readerTerminal = app.descendants(matching: .any).matching(identifier: "pane-terminal-reader").firstMatch
        waitFor(readerTerminal)
        readerTerminal.rightClick()

        let copyItemFromTerminal = app.windows.firstMatch.menuItems["Copy"]
        waitFor(copyItemFromTerminal)
        XCTAssertTrue(app.windows.firstMatch.menuItems["Paste"].exists)
        app.typeKey(.escape, modifierFlags: [])
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

        // Tab with no panes shows idle activity indicator
        let idleTabDot = app.descendants(matching: .any).matching(identifier: "tab-activity-idle-WorkTab").firstMatch
        XCTAssertTrue(idleTabDot.waitForExistence(timeout: 5))

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
        let idleTabDot2 = app.descendants(matching: .any).matching(identifier: "tab-activity-idle-WorkTab").firstMatch
        XCTAssertTrue(idleTabDot2.waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["pane-name-feature-b"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["pane-name-feature-c"].firstMatch.exists)
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
