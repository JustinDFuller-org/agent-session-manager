import XCTest

final class ScreenshotTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        try? Data("\"head\"".utf8).write(to: UITestAppSupport.directory.appending(path: "worktree-base-ref.json"))
    }

    func testWalkthrough() {
        // 1. Empty state
        waitFor(emptyStateHint)
        screenshot("empty-state")

        // 2. New tab sheet — empty, then filled
        app.typeKey("t", modifierFlags: .command)
        waitFor(app.textFields["new-tab-name-field"])
        screenshot("new-tab-sheet")
        app.textFields["new-tab-name-field"].typeText("Alpha")
        screenshot("new-tab-sheet-filled")
        app.buttons["new-tab-choose-dir-button"].click()
        let createBtn = app.buttons["new-tab-create-button"]
        waitFor(createBtn)
        createBtn.click()
        waitFor(app.buttons["tab-button-Alpha"].firstMatch)

        // 3. Main window with a tab
        screenshot("main-window-tab")

        // 4. New pane sheet open
        app.typeKey("p", modifierFlags: .command)
        waitFor(app.textFields["new-pane-name-field"])
        screenshot("new-pane-sheet")
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(app.textFields["new-pane-name-field"])

        // 5. Split panes
        createPane(named: "feature-a")
        screenshot("split-panes")

        // 6. Settings — General tab
        app.typeKey(",", modifierFlags: .command)
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()
        screenshot("settings-general")

        // 7. Settings — Notifications tab
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab)
        notificationsTab.click()
        screenshot("settings-notifications")

        // 8. Remaining settings tabs
        for (tab, name) in [
            ("Profiles", "settings-profiles"),
            ("Tools", "settings-tools"),
            ("CLI Options", "settings-cli-options"),
            ("Worktrees", "settings-worktrees"),
            ("Shortcuts", "settings-shortcuts"),
            ("Status Line", "settings-status-line"),
            ("Tracing", "settings-tracing"),
        ] {
            let btn = app.buttons[tab]
            waitFor(btn)
            btn.click()
            screenshot(name)
        }

        app.typeKey("w", modifierFlags: .command)
    }
}
