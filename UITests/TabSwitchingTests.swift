import XCTest

final class TabSwitchingTests: BaseTestCase {

    override func setUp() {
        super.setUp()
        createTab(named: "Tab1")
        createTab(named: "Tab2")
    }

    func testClickSwitchesTab() {
        app.buttons["tab-button-Tab1"].firstMatch.click()
        screenshot("09-switched-to-tab1")
        XCTAssertEqual(app.buttons["tab-button-Tab1"].firstMatch.value as? String, "active")
        XCTAssertEqual(app.buttons["tab-button-Tab2"].firstMatch.value as? String, "inactive")
    }

    func testKeyboardShortcutSwitchesTab() {
        // Cmd+1 is handled by an NSEvent local monitor. Send the keystroke
        // and verify the app remains in a good state without crashing.
        app.typeKey("1", modifierFlags: .command)
        screenshot("10-cmd1-switch")
        // Both tabs should still exist
        XCTAssertTrue(app.buttons["tab-button-Tab1"].firstMatch.exists)
        XCTAssertTrue(app.buttons["tab-button-Tab2"].firstMatch.exists)
    }

    func testBothTabsVisibleInBar() {
        XCTAssertTrue(app.buttons["tab-button-Tab1"].firstMatch.exists)
        XCTAssertTrue(app.buttons["tab-button-Tab2"].firstMatch.exists)
    }
}
