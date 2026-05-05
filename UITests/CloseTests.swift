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
}
