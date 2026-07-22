import XCTest

final class ScreenshotTests: BaseTestCase {
    private static var launchCount = 0

    override var additionalLaunchArguments: [String] {
        ["--uitesting-show-onboarding"]
    }

    override func setUp() {
        Self.launchCount += 1
        super.setUp()
    }

    override func prepareTestWorkspace() {
        let workspace = GitUITestWorkspace.directoryURL
        GitUITestWorkspace.runGitOrFail(["branch", "main"], cwd: workspace)
        GitUITestWorkspace.runGitOrFail(
            ["remote", "add", "origin", "https://github.com/test-owner/test-repository.git"],
            cwd: workspace
        )
        let support = UITestAppSupport.directory
        try? Data("{\"isEnabled\":true,\"branchName\":\"main\"}".utf8)
            .write(to: support.appending(path: "default-branch.json"))
        try? Data("\"head\"".utf8)
            .write(to: support.appending(path: "worktree-base-ref.json"))
    }

    override func tearDown() {
        XCTAssertEqual(Self.launchCount, 1, "ScreenshotTests must launch the app exactly once")
        super.tearDown()
    }

    func testWalkthrough() throws {
        captureOnboarding()

        waitFor(emptyStateHint)
        screenshot("empty-state")

        app.typeKey("t", modifierFlags: .command)
        waitFor(app.textFields["new-tab-name-field"])
        screenshot("new-tab-sheet")
        app.textFields["new-tab-name-field"].typeText("Alpha")
        let baseBranchField = app.textFields["new-tab-base-branch-field"]
        waitFor(baseBranchField)
        baseBranchField.click()
        baseBranchField.typeText("main")
        screenshot("new-tab-sheet-filled")
        baseBranchField.typeKey("a", modifierFlags: .command)
        baseBranchField.typeKey(.delete, modifierFlags: [])
        app.buttons["new-tab-choose-dir-button"].click()
        waitFor(app.buttons["new-tab-create-button"])
        app.buttons["new-tab-create-button"].click()
        waitFor(app.buttons["tab-button-Alpha"].firstMatch)
        screenshot("main-window-tab")

        app.typeKey("p", modifierFlags: .command)
        waitFor(app.textFields["new-pane-name-field"])
        screenshot("new-pane-sheet")
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(app.textFields["new-pane-name-field"])
        createPane(named: "feature-a")
        screenshot("split-panes")

        captureSettings()
        captureStatusIndicators()
        captureFocusedPane()
    }

    private func captureOnboarding() {
        let setupButton = app.buttons["onboarding-setup-button"]
        waitFor(setupButton)
        screenshot("onboarding-welcome")
        setupButton.click()

        let shellPicker = app.popUpButtons["onboarding-shell-picker"]
        waitFor(shellPicker)
        screenshot("onboarding-shell")
        app.buttons["onboarding-shell-continue-button"].click()

        let doneButton = app.buttons["onboarding-done-button"]
        waitFor(doneButton, timeout: 10)
        let enabled = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: doneButton)
        wait(for: [enabled], timeout: 15)
        screenshot("onboarding-tools")
        doneButton.click()

        let onboardingSheet = app.sheets.firstMatch
        waitFor(onboardingSheet)
        waitFor(app.buttons["onboarding-statusline-skip-button"], timeout: 10)
        waitFor(
            app.descendants(matching: .any)
                .matching(identifier: "settings-statusline-percentages-text-toggle").firstMatch
        )
        XCTAssertGreaterThan(onboardingSheet.frame.width, 520)
        XCTAssertGreaterThan(onboardingSheet.frame.height, 360)
        screenshot("onboarding-status-line")

        let statusLineSaveButton = app.buttons["onboarding-statusline-save-button"]
        let statusLineHittable = expectation(
            for: NSPredicate(format: "hittable == true"),
            evaluatedWith: statusLineSaveButton
        )
        wait(for: [statusLineHittable], timeout: 5)
        statusLineSaveButton.click()

        let cliFlagsSaveButton = app.buttons["onboarding-cliflags-save-button"]
        waitFor(cliFlagsSaveButton)
        let cliFlagsHittable = expectation(
            for: NSPredicate(format: "hittable == true"),
            evaluatedWith: cliFlagsSaveButton
        )
        wait(for: [cliFlagsHittable], timeout: 5)
        waitFor(
            app.descendants(matching: .any)
                .matching(identifier: "settings-cli-option-show---continue").firstMatch
        )
        screenshot("onboarding-cli-flags")
        cliFlagsSaveButton.click()

        let finishButton = app.buttons["onboarding-profiles-finish-button"]
        waitFor(finishButton)
        waitFor(app.descendants(matching: .any).matching(identifier: "profile-new-button").firstMatch)
        screenshot("onboarding-profiles")
        finishButton.click()
    }

    private func captureSettings() {
        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["AgentSessionManager Settings"]
        waitFor(settingsWindow)
        XCTAssertEqual(round(settingsWindow.frame.width), 900)
        XCTAssertEqual(round(settingsWindow.frame.height), 584)

        let tabs = [
            ("settings-sidebar-panes", "settings-panes"),
            ("settings-sidebar-notifications", "settings-notifications"),
            ("settings-sidebar-profiles", "settings-profiles"),
            ("settings-sidebar-tools", "settings-tools"),
            ("settings-sidebar-shortcuts", "settings-shortcuts"),
            ("settings-sidebar-status-line", "settings-status-line"),
            ("settings-sidebar-debug", "settings-debug"),
        ]
        for (identifier, screenshotName) in tabs {
            let tab = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            waitFor(tab)
            tab.click()
            screenshot(screenshotName)
        }
        app.typeKey("w", modifierFlags: .command)
    }

    private func captureStatusIndicators() {
        createTab(named: "Status")
        createPane(named: "running-pane")
        waitFor(
            app.descendants(matching: .any)
                .matching(identifier: "pane-activity-idle-running-pane").firstMatch,
            timeout: 15
        )
        waitFor(app.descendants(matching: .any).matching(identifier: "status-line-row").firstMatch)
        screenshot("pane-status-indicators")
    }

    private func captureFocusedPane() {
        createTab(named: "Focus")
        createPane(named: "reader")
        createPane(named: "worker")
        let readerHeader = app.descendants(matching: .any).matching(identifier: "pane-header-reader").firstMatch
        waitFor(readerHeader)
        readerHeader.doubleClick()
        waitFor(app.buttons["pane-show-all-reader"].firstMatch)
        screenshot("focused-pane")
        app.buttons["pane-show-all-reader"].click()
    }
}
