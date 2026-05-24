import XCTest

final class PaneLayoutTests: BaseTestCase {
    func testPaneHeadersRemainingAfterClosingOneOfThreePanes() {
        createTab(named: "LayoutTestTab")
        createPane(named: "pane-one")
        createPane(named: "pane-two")
        createPane(named: "pane-three")

        waitFor(app.staticTexts["pane-name-pane-three"].firstMatch)

        app.buttons["pane-close-pane-three"].firstMatch.click()
        waitForDisappear(app.staticTexts["pane-name-pane-three"].firstMatch)

        screenshot("pane-layout-after-close")

        XCTAssertTrue(app.otherElements["pane-header-pane-one"].firstMatch.exists)
        XCTAssertTrue(app.otherElements["pane-header-pane-two"].firstMatch.exists)
    }
}
