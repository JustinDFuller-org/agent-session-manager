import XCTest

final class ProfileOrderingTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        clearProfilesSetting()
    }

    override func tearDown() {
        clearProfilesSetting()
        super.tearDown()
    }

    func testMoveUpButtonExistsOnNonFirstProfile() {
        createTwoProfiles()

        let profilesTab = app.buttons["Profiles"]
        waitFor(profilesTab)
        profilesTab.click()

        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'profile-move-down-'"))
        XCTAssertGreaterThan(rows.count, 0, "Expected at least one move-down button")
    }

    func testMoveDownButtonExistsOnNonLastProfile() {
        createTwoProfiles()

        let profilesTab = app.buttons["Profiles"]
        waitFor(profilesTab)
        profilesTab.click()

        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'profile-move-up-'"))
        XCTAssertGreaterThan(rows.count, 0, "Expected at least one move-up button")
    }

    func testMoveDownSwapsProfileOrder() {
        createTwoProfiles()

        let profilesTab = app.buttons["Profiles"]
        waitFor(profilesTab)
        profilesTab.click()

        let profileNames = app.staticTexts.matching(
            NSPredicate(format: "value == 'Alpha' OR value == 'Beta'"))
        let nameBefore = profileNames.firstMatch.value as? String

        let moveDownButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'profile-move-down-'"))
        moveDownButtons.firstMatch.click()

        let nameAfter = profileNames.firstMatch.value as? String
        XCTAssertNotEqual(nameBefore, nameAfter, "Profile order should have swapped after move-down")
    }

    private func createTwoProfiles() {
        openSettings()
        let profilesTab = app.buttons["Profiles"]
        waitFor(profilesTab)
        profilesTab.click()

        createProfile(named: "Alpha")
        createProfile(named: "Beta")
    }

    private func createProfile(named name: String) {
        let newProfileButton = app.buttons["New Profile"]
        waitFor(newProfileButton)
        newProfileButton.click()

        let nameField = app.textFields.firstMatch
        waitFor(nameField)
        nameField.click()
        nameField.typeText(name)

        let saveButton = app.buttons["Save"]
        waitFor(saveButton)
        saveButton.click()
    }

    private func openSettings() {
        app.typeKey(",", modifierFlags: .command)
    }

    private func clearProfilesSetting() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let file = support.appending(path: "agent-session-manager/profiles.json")
        try? FileManager.default.removeItem(at: file)
    }
}
