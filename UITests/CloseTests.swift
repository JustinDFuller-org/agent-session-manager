import XCTest

final class CloseTests: BaseTestCase {
    func testCloseTabButton() {
        createTab(named: "CloseableTab")
        let tabButton = app.buttons["tab-button-CloseableTab"].firstMatch
        XCTAssertTrue(tabButton.exists)

        app.buttons["tab-close-CloseableTab"].firstMatch.click()
        screenshot("11-after-close-tab")

        waitForDisappear(tabButton)
        // Verify the app is in a usable state (empty state hint is shown)
        waitFor(app.staticTexts["empty-state-hint"])
    }

    func testClosePane() {
        createTab(named: "PaneCloseTab")
        createPane(named: "pane-to-close")

        let paneName = app.staticTexts["pane-to-close"].firstMatch
        waitFor(paneName)

        app.buttons["close-pane-to-close"].firstMatch.click()
        screenshot("12-after-close-pane")

        waitForDisappear(paneName)
    }

    func testCloseTabViaKeyboardShortcut() {
        createTab(named: "KeepTab")
        createTab(named: "CloseTab")
        waitFor(app.buttons["tab-button-CloseTab"].firstMatch)

        app.typeKey("k", modifierFlags: .command)
        screenshot("13-after-close-tab-shortcut")

        waitForDisappear(app.buttons["tab-button-CloseTab"].firstMatch)
        XCTAssertTrue(app.buttons["tab-button-KeepTab"].firstMatch.exists)
    }

    func testCloseTabViaMenuItem() {
        createTab(named: "KeepTab")
        createTab(named: "CloseTab")
        waitFor(app.buttons["tab-button-CloseTab"].firstMatch)

        app.menuBars.menuBarItems["File"].click()
        let menuItem = app.menuBars.menuBarItems["File"].menuItems["Close Tab"]
        waitFor(menuItem)
        XCTAssertTrue(menuItem.isEnabled)
        menuItem.click()

        waitForDisappear(app.buttons["tab-button-CloseTab"].firstMatch)
        XCTAssertTrue(app.buttons["tab-button-KeepTab"].firstMatch.exists)
    }

    func testCloseTabMenuItemDisabledWithNoTabs() {
        app.menuBars.menuBarItems["File"].click()
        let menuItem = app.menuBars.menuBarItems["File"].menuItems["Close Tab"]
        waitFor(menuItem)
        XCTAssertFalse(menuItem.isEnabled)
    }
}
