import XCTest

final class ScreenshotTests: BaseTestCase {
    func testEmptyState() {
        waitFor(emptyStateHint)
        screenshot("empty-state")
    }

    func testMainWindowWithTab() {
        createTab(named: "Alpha")
        screenshot("main-window-tab")
    }

    func testNewPaneSheet() {
        createTab(named: "Alpha")
        app.typeKey("p", modifierFlags: .command)
        let field = app.textFields["new-pane-name-field"]
        waitFor(field)
        screenshot("new-pane-sheet")
        app.typeKey(.escape, modifierFlags: [])
    }

    func testSplitPanes() {
        createTab(named: "Alpha")
        createPane(named: "feature-a")
        screenshot("split-panes")
    }

    func testSettingsGeneral() {
        app.typeKey(",", modifierFlags: .command)
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()
        screenshot("settings-general")
        app.typeKey("w", modifierFlags: .command)
    }

    func testSettingsNotifications() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab)
        notificationsTab.click()
        screenshot("settings-notifications")
        app.typeKey("w", modifierFlags: .command)
    }
}
