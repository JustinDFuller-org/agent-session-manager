import XCTest

final class OnboardingScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
        super.tearDown()
    }

    func testOnboardingWizardScreenshots() {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        app.launch()
        app.activate()

        let setupButton = app.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        screenshot("onboarding-welcome", app: app)

        setupButton.click()

        let shellPicker = app.popUpButtons["onboarding-shell-picker"]
        XCTAssertTrue(shellPicker.waitForExistence(timeout: 5))
        screenshot("onboarding-shell", app: app)

        let continueButton = app.buttons["onboarding-shell-continue-button"]
        continueButton.click()

        let doneButton = app.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        let enabled = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: doneButton)
        wait(for: [enabled], timeout: 15)
        screenshot("onboarding-tools", app: app)

        doneButton.click()

        let onboardingSheet = app.sheets.firstMatch
        XCTAssertTrue(onboardingSheet.waitForExistence(timeout: 5))

        let statusLineSkipButton = app.buttons["onboarding-statusline-skip-button"]
        XCTAssertTrue(statusLineSkipButton.waitForExistence(timeout: 10))
        let statusLineToggle = app.descendants(matching: .any)
            .matching(identifier: "settings-statusline-percentages-text-toggle").firstMatch
        XCTAssertTrue(statusLineToggle.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(onboardingSheet.frame.width, 520)
        XCTAssertGreaterThan(onboardingSheet.frame.height, 360)
        screenshot("onboarding-status-line", app: app)

        let statusLineSaveButton = app.buttons["onboarding-statusline-save-button"]
        let statusLineSaveHittable = expectation(
            for: NSPredicate(format: "hittable == true"),
            evaluatedWith: statusLineSaveButton)
        wait(for: [statusLineSaveHittable], timeout: 5)
        statusLineSaveButton.click()

        let cliFlagsSaveButton = app.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))
        let cliFlagsSaveHittable = expectation(
            for: NSPredicate(format: "hittable == true"),
            evaluatedWith: cliFlagsSaveButton)
        wait(for: [cliFlagsSaveHittable], timeout: 5)
        let cliOptionToggle = app.descendants(matching: .any)
            .matching(identifier: "settings-cli-option-show---continue").firstMatch
        XCTAssertTrue(cliOptionToggle.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(onboardingSheet.frame.width, 520)
        XCTAssertGreaterThan(onboardingSheet.frame.height, 360)
        screenshot("onboarding-cli-flags", app: app)

        cliFlagsSaveButton.click()

        let finishButton = app.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        let newProfileButton = app.descendants(matching: .any)
            .matching(identifier: "profile-new-button").firstMatch
        XCTAssertTrue(newProfileButton.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(onboardingSheet.frame.width, 520)
        XCTAssertGreaterThan(onboardingSheet.frame.height, 360)
        screenshot("onboarding-profiles", app: app)

        finishButton.click()
    }
}
