import XCTest

final class AppLaunchTests: BaseTestCase {

    func testLaunchShowsEmptyState() {
        waitFor(emptyStateHint)
        screenshot("01-empty-state")
    }

    func testEmptyStateHintMentionsOnlyTabShortcut() {
        waitFor(emptyStateHint)
        // macOS 26+ SwiftUI stores StaticText content in .value, not .label
        XCTAssertEqual(emptyStateHint.value as? String, "Press ⌘T to create a tab")
    }

    func testNewTabShortcutOpensSheet() {
        app.typeKey("t", modifierFlags: .command)
        waitFor(app.textFields["new-tab-name-field"])
        XCTAssertTrue(app.textFields["new-tab-name-field"].isEnabled)
    }

    func testNewPaneMenuItemDisabledWithNoTabs() {
        app.menuBars.menuBarItems["File"].click()
        let menuItem = app.menuBars.menuBarItems["File"].menuItems["New Pane in Current Tab"]
        waitFor(menuItem)
        XCTAssertFalse(menuItem.isEnabled)
        app.typeKey(.escape, modifierFlags: [])
    }
}
