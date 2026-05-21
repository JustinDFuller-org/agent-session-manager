import XCTest

final class TabLoadingIndicatorUITests: BaseTestCase {
    func testLoadingDotAbsentOnIdleTabWithNoPanes() {
        createTab(named: "idle-tab")
        let dot = app.otherElements["tab-loading-dot-idle-tab"].firstMatch
        XCTAssertFalse(dot.exists, "Loading dot should not appear on a tab with no running panes")
    }

    func testLoadingDotAbsentOnTabWithPaneInUITestingMode() {
        createTab(named: "pane-tab")
        createPane(named: "test-pane")
        let dot = app.otherElements["tab-loading-dot-pane-tab"].firstMatch
        XCTAssertFalse(
            dot.exists,
            "Loading dot should not appear when no real process is running (UI testing mode skips process start)"
        )
    }
}
