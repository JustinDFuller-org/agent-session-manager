import XCTest

final class AppLaunchTests: BaseTestCase {

    func testLaunchShowsEmptyState() {
        waitFor(emptyStateHint)
        screenshot("01-empty-state")
    }

    func testNewTabButtonExistsOnLaunch() {
        let newTabButton = app.buttons["new-tab-button"]
        waitFor(newTabButton)
        XCTAssertTrue(newTabButton.isEnabled)
    }
}
