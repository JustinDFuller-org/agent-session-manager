import XCTest

final class FileMenuTests: BaseTestCase {
    func testNewPaneMenuItemEnabledAfterCreatingTab() {
        createTab(named: "MenuTestTab")

        app.menuBars.menuBarItems["File"].click()
        let menuItem = app.menuBars.menuBarItems["File"].menuItems["New Pane in Current Tab"]
        waitFor(menuItem)
        XCTAssertTrue(menuItem.isEnabled)
        app.typeKey(.escape, modifierFlags: [])
        screenshot("menu-pane-enabled")
    }
}
