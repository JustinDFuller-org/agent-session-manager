import XCTest

final class ScreenshotTests: BaseTestCase {
    private static var launchCount = 0
    private var githubFixture: ScreenshotGitHubFixture!

    override var additionalLaunchArguments: [String] {
        ["--uitesting-show-onboarding"]
    }

    override var additionalLaunchEnvironment: [String: String] {
        githubFixture?.launchEnvironment ?? [:]
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
        try? Data(
            #"{"intervalSeconds":15,"timeoutSeconds":5,"backgroundRefreshEnabled":true,"backgroundIntervalSeconds":15}"#
                .utf8
        ).write(to: support.appending(path: "pr-polling-settings.json"))
        githubFixture = ScreenshotGitHubFixture()
    }

    override func tearDown() {
        XCTAssertEqual(Self.launchCount, 1, "ScreenshotTests must launch the app exactly once")
        let fixtureDirectory = githubFixture?.directory
        super.tearDown()
        if let fixtureDirectory {
            try? FileManager.default.removeItem(at: fixtureDirectory)
        }
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
        captureActivityIndicators()
        captureFocusedPane()
        capturePRNotification()
        captureTraceDashboard()
        try captureInvariantDashboard()
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

    private func captureActivityIndicators() {
        createTab(named: "Activity")
        createPane(named: "activity-source")

        let idlePane = openShellHere(from: "activity-source")
        let waitingPane = openShellHere(from: "activity-source")
        XCTAssertNotEqual(idlePane, waitingPane)
        typeTerminalCommand("printf '\\a'")
        waitFor(
            app.descendants(matching: .any)
                .matching(identifier: "pane-activity-waiting-\(waitingPane)").firstMatch,
            timeout: 10
        )
        waitFor(
            app.descendants(matching: .any)
                .matching(identifier: "pane-activity-idle-\(idlePane)").firstMatch,
            timeout: 10
        )
        screenshot("activity-indicator-states")
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

    private func capturePRNotification() {
        createTab(named: "PR")
        createPane(named: "pr-pane")
        waitFor(app.staticTexts["#42 (open)"], timeout: 45)
        githubFixture.markMerged()

        let row = app.descendants(matching: .any)
            .matching(identifier: "notification-row-pr-pane").firstMatch
        waitFor(row, timeout: 45)
        screenshot("notification-sidebar")
        row.click()
        waitFor(app.staticTexts["PR Merged"], timeout: 5)
        screenshot("pr-merged-alert")
        app.windows.firstMatch.buttons["Cancel"].firstMatch.click()
    }

    private func captureTraceDashboard() {
        app.typeKey(",", modifierFlags: .command)
        let debugTab = app.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-debug").firstMatch
        waitFor(debugTab)
        debugTab.click()
        let debugToggle = app.checkBoxes["settings-debug-mode-toggle"]
        waitFor(debugToggle)
        if debugToggle.value as? Int == 0 {
            debugToggle.click()
        }
        app.typeKey("w", modifierFlags: .command)

        createTab(named: "trace-demo")
        createPane(named: "trace-worker")
        app.typeKey("d", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Trace Dashboard"]
        waitFor(dashboard)
        XCTAssertEqual(round(dashboard.frame.width), 900)
        XCTAssertEqual(round(dashboard.frame.height), 664)
        let refreshButton = dashboard.buttons["trace-dashboard-refresh-button"]
        waitFor(refreshButton)
        refreshButton.click()
        let paneRow = dashboard.descendants(matching: .any)
            .matching(identifier: "trace-dashboard-pane-row").firstMatch
        waitFor(paneRow, timeout: 10)
        paneRow.click()
        waitFor(dashboard.textFields["trace-dashboard-filter-field"], timeout: 10)
        screenshot("trace-dashboard")

        let traceRow = dashboard.descendants(matching: .any)
            .matching(identifier: "trace-dashboard-list-row").firstMatch
        waitFor(traceRow, timeout: 10)
        traceRow.click()
        waitFor(
            dashboard.descendants(matching: .any)
                .matching(identifier: "trace-dashboard-waterfall").firstMatch,
            timeout: 10
        )
        screenshot("trace-waterfall")
    }

    private func captureInvariantDashboard() throws {
        app.typeKey(",", modifierFlags: .command)
        let debugTab = app.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-debug").firstMatch
        waitFor(debugTab)
        debugTab.click()
        let debugToggle = app.checkBoxes["settings-debug-mode-toggle"]
        waitFor(debugToggle)
        if debugToggle.value as? Int == 0 {
            debugToggle.click()
        }
        app.typeKey("w", modifierFlags: .command)

        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let existingStatusFiles = Set(
            (try? FileManager.default.contentsOfDirectory(
                at: temporaryDirectory,
                includingPropertiesForKeys: nil
            ))?
            .filter { $0.lastPathComponent.hasPrefix("agent-session-manager-status-") }
            .map(\.path) ?? []
        )
        createTab(named: "invariant-demo")
        createPane(named: "invariant-worker")

        let monitorFileExpectation = expectation(description: "Claude status-line monitor file exists")
        var monitorFile: URL?
        let deadline = Date().addingTimeInterval(10)
        repeat {
            monitorFile =
                (try? FileManager.default.contentsOfDirectory(
                    at: temporaryDirectory,
                    includingPropertiesForKeys: nil
                ))?
                .first {
                    $0.lastPathComponent.hasPrefix("agent-session-manager-status-")
                        && !existingStatusFiles.contains($0.path)
                }
            if monitorFile != nil {
                monitorFileExpectation.fulfill()
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        wait(for: [monitorFileExpectation], timeout: 0.1)
        XCTAssertNotNil(monitorFile)
        try Data(#"{"worktree":{"name":"wrong-name","branch":"main"}}"#.utf8)
            .write(to: XCTUnwrap(monitorFile))

        app.typeKey("i", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Invariant Dashboard"]
        waitFor(dashboard)
        XCTAssertEqual(round(dashboard.frame.width), 900)
        XCTAssertEqual(round(dashboard.frame.height), 664)
        let refreshButton = dashboard.buttons["invariant-dashboard-refresh-button"]
        waitFor(refreshButton)
        let violation = dashboard.staticTexts["statusline.worktree.name"]
        let violationDeadline = Date().addingTimeInterval(10)
        repeat {
            refreshButton.click()
            if violation.exists { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < violationDeadline
        XCTAssertTrue(violation.exists, "Expected the real worktree-name violation to appear")
        waitFor(
            dashboard.descendants(matching: .any)
                .matching(identifier: "invariant-dashboard-row").firstMatch,
            timeout: 10
        )
        screenshot("invariant-dashboard")
    }
}
