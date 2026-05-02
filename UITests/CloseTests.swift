import XCTest

final class CloseTests: BaseTestCase {

    func testCloseTabButton() {
        createTab(named: "CloseableTab")
        let tabButton = app.buttons["tab-button-CloseableTab"].firstMatch
        XCTAssertTrue(tabButton.exists)

        app.buttons["tab-close-CloseableTab"].firstMatch.click()
        screenshot("11-after-close-tab")

        waitForDisappear(tabButton)
        // Verify the new-tab button is still available (app is in a usable state)
        XCTAssertTrue(app.buttons["new-tab-button"].exists)
    }

    func testClosePane() {
        createTab(named: "PaneCloseTab")
        createPane(named: "pane-to-close")

        let paneHeader = app.groups["pane-header-pane-to-close"]
        waitFor(paneHeader)

        app.buttons["pane-close-pane-to-close"].firstMatch.click()
        screenshot("12-after-close-pane")

        waitForDisappear(paneHeader)
    }
}
