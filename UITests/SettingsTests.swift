import XCTest

final class SettingsTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        clearDefaultBranchSetting()
    }

    override func tearDown() {
        clearDefaultBranchSetting()
        super.tearDown()
    }

    func testGeneralTabShowsDefaultBranchField() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let field = app.textFields["settings-default-branch-field"]
        waitFor(field)
        XCTAssertTrue(field.exists)
    }

    func testDefaultBranchFieldDefaultsToMain() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let field = app.textFields["settings-default-branch-field"]
        waitFor(field)
        XCTAssertEqual(field.value as? String, "main")
    }

    func testDefaultBranchFieldAcceptsInput() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let field = app.textFields["settings-default-branch-field"]
        waitFor(field)
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("develop")

        XCTAssertEqual(field.value as? String, "develop")
    }

    func testDefaultBranchToggleExists() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-default-branch-toggle"]
        waitFor(toggle)
        XCTAssertTrue(toggle.exists)
    }

    func testDefaultBranchFieldHiddenWhenDisabled() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-default-branch-toggle"]
        waitFor(toggle)
        toggle.click()

        let field = app.textFields["settings-default-branch-field"]
        XCTAssertFalse(field.waitForExistence(timeout: 0.5))
    }

    func testDefaultBranchFieldVisibleWhenReEnabled() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-default-branch-toggle"]
        waitFor(toggle)
        toggle.click()
        toggle.click()

        let field = app.textFields["settings-default-branch-field"]
        waitFor(field)
        XCTAssertTrue(field.exists)
    }

    func testContinueOnRestartToggleExists() {
        openSettings()
        let toggle = app.checkBoxes["settings-continue-on-restart-toggle"]
        waitFor(toggle)
        XCTAssertTrue(toggle.exists)
    }

    func testContinueOnRestartToggleDefaultsToOn() {
        openSettings()
        let toggle = app.checkBoxes["settings-continue-on-restart-toggle"]
        waitFor(toggle)
        XCTAssertEqual(toggle.value as? Int, 1)
    }

    private func openSettings() {
        app.typeKey(",", modifierFlags: .command)
    }

    private func clearDefaultBranchSetting() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let file = support.appending(path: "agent-session-manager/default-branch.json")
        try? FileManager.default.removeItem(at: file)
    }
}
