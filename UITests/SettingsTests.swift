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
