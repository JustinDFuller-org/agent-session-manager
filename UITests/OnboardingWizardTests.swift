import XCTest

final class OnboardingWizardTests: BaseTestCase {
    // MARK: - Wizard suppressed on normal launch (onboarding already done)

    func testWizardDoesNotAppearWhenOnboardingComplete() {
        // BaseTestCase launches with --uitesting-skip-restore, so no onboarding file exists,
        // but isUITesting == true suppresses the wizard without --uitesting-show-onboarding.
        let setupButton = app.buttons["onboarding-setup-button"]
        XCTAssertFalse(setupButton.waitForExistence(timeout: 1))
    }

    // MARK: - Wizard shown when forced via launch arg

    func testWizardAppearsWithShowOnboardingArg() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))

        forcedApp.terminate()
    }

    func testSkipDismissesWizard() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let skipButton = forcedApp.buttons["onboarding-skip-button"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.click()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertFalse(setupButton.waitForExistence(timeout: 2))

        forcedApp.terminate()
    }

    func testWelcomeStepNavigatesToShell() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let shellPicker = forcedApp.popUpButtons["onboarding-shell-picker"]
        XCTAssertTrue(shellPicker.waitForExistence(timeout: 5))

        forcedApp.terminate()
    }

    func testShellStepNavigatesToTools() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))

        forcedApp.terminate()
    }

    func testDoneButtonDismissesWizard() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        // Walk through: Welcome → Shell → Tools → Status Line → CLI Flags → Profiles → Finish
        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let saveButton = forcedApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.click()

        let cliFlagsSaveButton = forcedApp.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))
        cliFlagsSaveButton.click()

        let finishButton = forcedApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.click()

        XCTAssertFalse(forcedApp.buttons["onboarding-profiles-finish-button"].waitForExistence(timeout: 2))

        forcedApp.terminate()
    }

    func testStatusLineStepAppearsAfterTools() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let skipButton = forcedApp.buttons["onboarding-statusline-skip-button"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))

        forcedApp.terminate()
    }

    func testWizardSkipStatusLineDismissesWizard() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSkipButton = forcedApp.buttons["onboarding-statusline-skip-button"]
        XCTAssertTrue(statusLineSkipButton.waitForExistence(timeout: 5))
        statusLineSkipButton.click()

        let cliFlagsSkipButton = forcedApp.buttons["onboarding-cliflags-skip-button"]
        XCTAssertTrue(cliFlagsSkipButton.waitForExistence(timeout: 5))
        cliFlagsSkipButton.click()

        let finishButton = forcedApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.click()

        XCTAssertFalse(forcedApp.buttons["onboarding-profiles-finish-button"].waitForExistence(timeout: 2))

        forcedApp.terminate()
    }

    func testClearButtonShownOnDefaultLayout() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let clearButton = forcedApp.buttons["onboarding-statusline-clear-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        XCTAssertFalse(forcedApp.buttons["onboarding-statusline-reset-button"].exists)

        forcedApp.terminate()
    }

    func testResetButtonShownAfterClearing() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let clearButton = forcedApp.buttons["onboarding-statusline-clear-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.click()

        let resetButton = forcedApp.buttons["onboarding-statusline-reset-button"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        XCTAssertFalse(forcedApp.buttons["onboarding-statusline-clear-button"].exists)

        forcedApp.terminate()
    }

    // MARK: - CLI Flags step

    func testCliFlagsStepAppearsAfterStatusLine() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = forcedApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let cliFlagsSaveButton = forcedApp.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))

        forcedApp.terminate()
    }

    func testCliFlagsSkipAdvancesToProfiles() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = forcedApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let cliFlagsSkipButton = forcedApp.buttons["onboarding-cliflags-skip-button"]
        XCTAssertTrue(cliFlagsSkipButton.waitForExistence(timeout: 5))
        cliFlagsSkipButton.click()

        let finishButton = forcedApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))

        forcedApp.terminate()
    }

    func testCliFlagsClearButtonShownOnRecommendedDefaults() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = forcedApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let clearButton = forcedApp.buttons["onboarding-cliflags-clear-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        XCTAssertFalse(forcedApp.buttons["onboarding-cliflags-reset-button"].exists)

        forcedApp.terminate()
    }

    func testCliFlagsResetButtonShownAfterClearing() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = forcedApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let clearButton = forcedApp.buttons["onboarding-cliflags-clear-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.click()

        let resetButton = forcedApp.buttons["onboarding-cliflags-reset-button"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        XCTAssertFalse(forcedApp.buttons["onboarding-cliflags-clear-button"].exists)

        forcedApp.terminate()
    }

    // MARK: - Profiles step

    func testProfilesStepAppearsAfterCliFlags() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = forcedApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let cliFlagsSaveButton = forcedApp.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))
        cliFlagsSaveButton.click()

        let finishButton = forcedApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))

        forcedApp.terminate()
    }

    func testProfilesFinishDismissesWizard() {
        app.terminate()
        clearPersistedState()

        let forcedApp = XCUIApplication()
        forcedApp.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        forcedApp.launch()
        forcedApp.activate()

        let setupButton = forcedApp.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        setupButton.click()

        let continueButton = forcedApp.buttons["onboarding-shell-continue-button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.click()

        let doneButton = forcedApp.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.click()

        let statusLineSaveButton = forcedApp.buttons["onboarding-statusline-save-button"]
        XCTAssertTrue(statusLineSaveButton.waitForExistence(timeout: 5))
        statusLineSaveButton.click()

        let cliFlagsSaveButton = forcedApp.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))
        cliFlagsSaveButton.click()

        let finishButton = forcedApp.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.click()

        XCTAssertFalse(forcedApp.buttons["onboarding-profiles-finish-button"].waitForExistence(timeout: 2))

        forcedApp.terminate()
    }
}
