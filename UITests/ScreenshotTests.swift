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

        // 2. Main window with a tab
        createTab(named: "Alpha")
        screenshot("main-window-tab")

        // 3. New pane sheet open
        app.typeKey("p", modifierFlags: .command)
        waitFor(app.textFields["new-pane-name-field"])
        screenshot("new-pane-sheet")
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(app.textFields["new-pane-name-field"])

        // 4. Split panes
        createPane(named: "feature-a")
        screenshot("split-panes")

        // 5. Settings — General tab
        app.typeKey(",", modifierFlags: .command)
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()
        screenshot("settings-general")

        // 6. Settings — Notifications tab
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab)
        notificationsTab.click()
        screenshot("settings-notifications")

        app.typeKey("w", modifierFlags: .command)
    }
}
