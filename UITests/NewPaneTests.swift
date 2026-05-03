import XCTest

final class NewPaneTests: BaseTestCase {

    override func setUp() {
        super.setUp()
        createTab(named: "PaneTestTab")
    }

    func testCreatePane() {
        app.typeKey("p", modifierFlags: .command)

        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        screenshot("06-new-pane-sheet")

        nameField.click()
        nameField.typeText("auth-refactor")

        let openButton = app.buttons["new-pane-open-button"]
        XCTAssertTrue(openButton.isEnabled)
        openButton.click()

        let paneHeader = app.groups["pane-header-auth-refactor"]
        waitFor(paneHeader)
        screenshot("07-pane-created")
        XCTAssertTrue(paneHeader.exists)
    }

    func testOpenButtonDisabledWithEmptyName() {
        app.typeKey("p", modifierFlags: .command)
        waitFor(app.textFields["new-pane-name-field"])
        XCTAssertFalse(app.buttons["new-pane-open-button"].isEnabled)
    }

    func testCancelDismissesSheet() {
        app.typeKey("p", modifierFlags: .command)
        waitFor(app.textFields["new-pane-name-field"])
        app.buttons["new-pane-cancel-button"].click()
        XCTAssertFalse(app.textFields["new-pane-name-field"].exists)
    }

    func testCreatePaneViaKeyboardShortcut() {
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        screenshot("08-new-pane-via-shortcut")
        XCTAssertTrue(nameField.exists)
    }

    func testTabEmptyStateHintMentionsPaneShortcut() {
        waitFor(app.staticTexts["tab-empty-state-PaneTestTab"])
        XCTAssertEqual(app.staticTexts["tab-empty-state-PaneTestTab"].label, "Press ⌘P to open a pane")
    }

    func testNewPaneMenuItemOpensSheet() {
        app.menuBars.menuBarItems["File"].click()
        let menuItem = app.menuBars.menuBarItems["File"].menuItems["New Pane in Current Tab"]
        waitFor(menuItem)
        XCTAssertTrue(menuItem.isEnabled)
        menuItem.click()
        waitFor(app.textFields["new-pane-name-field"])
        screenshot("08b-new-pane-via-menu")
    }

    func testCreateMultiplePanesInOneTab() {
        createPane(named: "feature-a")
        screenshot("09a-one-pane")

        createPane(named: "feature-b")
        screenshot("09b-two-panes")

        createPane(named: "feature-c")
        screenshot("09c-three-panes")

        XCTAssertTrue(app.groups["pane-header-feature-a"].firstMatch.exists)
        XCTAssertTrue(app.groups["pane-header-feature-b"].firstMatch.exists)
        XCTAssertTrue(app.groups["pane-header-feature-c"].firstMatch.exists)
    }

    func testClosingOnePaneKeepsOthers() {
        createPane(named: "keep-pane")
        createPane(named: "close-pane")

        waitFor(app.groups["pane-header-keep-pane"])
        waitFor(app.groups["pane-header-close-pane"])
        screenshot("10a-two-panes-before-close")

        app.buttons["pane-close-close-pane"].firstMatch.click()
        screenshot("10b-one-pane-after-close")

        XCTAssertTrue(app.groups["pane-header-keep-pane"].firstMatch.exists)
        XCTAssertFalse(app.groups["pane-header-close-pane"].exists)
    }

    func testFourPanesGridLayout() {
        createPane(named: "pane-1")
        createPane(named: "pane-2")
        createPane(named: "pane-3")
        createPane(named: "pane-4")

        screenshot("11-four-pane-grid")

        XCTAssertTrue(app.groups["pane-header-pane-1"].firstMatch.exists)
        XCTAssertTrue(app.groups["pane-header-pane-2"].firstMatch.exists)
        XCTAssertTrue(app.groups["pane-header-pane-3"].firstMatch.exists)
        XCTAssertTrue(app.groups["pane-header-pane-4"].firstMatch.exists)
    }
}
