import XCTest

final class OnboardingWizardTests: BaseTestCase {
    // MARK: - Wizard suppressed on normal launch (onboarding already done)

    func testWizardDoesNotAppearWhenOnboardingComplete() {
        // BaseTestCase writes onboarding-settings.json with hasCompletedOnboarding=true,
        // so the wizard is suppressed by the real onboarding guard.
        let setupButton = app.buttons["onboarding-setup-button"]
        XCTAssertFalse(setupButton.waitForExistence(timeout: 1))
    }

    // MARK: - Wizard shown when onboarding is not yet complete

    func testWizardAppearsWhenOnboardingNotComplete() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))

        freshApp.terminate()
    }

    func testSkipDismissesWizard() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let skipButton = freshApp.buttons["onboarding-skip-button"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.click()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertFalse(setupButton.waitForExistence(timeout: 2))

        freshApp.terminate()
    }

    func testWelcomeStepNavigatesToShell() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let shellPicker = freshApp.popUpButtons["onboarding-shell-picker"]
        XCTAssertTrue(shellPicker.waitForExistence(timeout: 5))

        freshApp.terminate()
    }

    func testShellStepNavigatesToTools() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))

        freshApp.terminate()
    }

    func testDoneButtonDismissesWizard() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let saveButton = freshApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.click()

        let cliFlagsSaveButton = freshApp.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))
        cliFlagsSaveButton.click()

        let finishButton = freshApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.click()

        XCTAssertFalse(freshApp.buttons["onboarding-profiles-finish-button"].waitForExistence(timeout: 2))

        freshApp.terminate()
    }

    func testStatusLineStepAppearsAfterTools() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let skipButton = freshApp.buttons["onboarding-statusline-skip-button"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))

        freshApp.terminate()
    }

    func testWizardSkipStatusLineDismissesWizard() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSkipButton = freshApp.buttons["onboarding-statusline-skip-button"]
        XCTAssertTrue(statusLineSkipButton.waitForExistence(timeout: 5))
        statusLineSkipButton.click()

        let cliFlagsSkipButton = freshApp.buttons["onboarding-cliflags-skip-button"]
        XCTAssertTrue(cliFlagsSkipButton.waitForExistence(timeout: 5))
        cliFlagsSkipButton.click()

        let finishButton = freshApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.click()

        XCTAssertFalse(freshApp.buttons["onboarding-profiles-finish-button"].waitForExistence(timeout: 2))

        freshApp.terminate()
    }

    func testClearButtonShownOnDefaultLayout() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let clearButton = freshApp.buttons["onboarding-statusline-clear-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        XCTAssertFalse(freshApp.buttons["onboarding-statusline-reset-button"].exists)

        freshApp.terminate()
    }

    func testResetButtonShownAfterClearing() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let clearButton = freshApp.buttons["onboarding-statusline-clear-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.click()

        let resetButton = freshApp.buttons["onboarding-statusline-reset-button"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        XCTAssertFalse(freshApp.buttons["onboarding-statusline-clear-button"].exists)

        freshApp.terminate()
    }

    // MARK: - CLI Flags step

    func testCliFlagsStepAppearsAfterStatusLine() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = freshApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let cliFlagsSaveButton = freshApp.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))

        freshApp.terminate()
    }

    func testCliFlagsSkipAdvancesToProfiles() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = freshApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let cliFlagsSkipButton = freshApp.buttons["onboarding-cliflags-skip-button"]
        XCTAssertTrue(cliFlagsSkipButton.waitForExistence(timeout: 5))
        cliFlagsSkipButton.click()

        let finishButton = freshApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))

        freshApp.terminate()
    }

    func testCliFlagsClearButtonShownOnRecommendedDefaults() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = freshApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let clearButton = freshApp.buttons["onboarding-cliflags-clear-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        XCTAssertFalse(freshApp.buttons["onboarding-cliflags-reset-button"].exists)

        freshApp.terminate()
    }

    func testCliFlagsResetButtonShownAfterClearing() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = freshApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let clearButton = freshApp.buttons["onboarding-cliflags-clear-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.click()

        let resetButton = freshApp.buttons["onboarding-cliflags-reset-button"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        XCTAssertFalse(freshApp.buttons["onboarding-cliflags-clear-button"].exists)

        freshApp.terminate()
    }

    // MARK: - Profiles step

    func testProfilesStepAppearsAfterCliFlags() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = freshApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let cliFlagsSaveButton = freshApp.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))
        cliFlagsSaveButton.click()

        let finishButton = freshApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))

        freshApp.terminate()
    }

    func testProfilesFinishDismissesWizard() {
        app.terminate()
        clearPersistedState()

        let freshApp = XCUIApplication()
        freshApp.launch()
        freshApp.activate()

        let setupButton = freshApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = freshApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = freshApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = freshApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let cliFlagsSaveButton = freshApp.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))
        cliFlagsSaveButton.click()

        let finishButton = freshApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.click()

        XCTAssertFalse(freshApp.buttons["onboarding-profiles-finish-button"].waitForExistence(timeout: 2))

        freshApp.terminate()
    }
}
