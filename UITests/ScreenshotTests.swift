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
        let support = UITestAppSupport.directory
        try? Data("{\"isEnabled\":true,\"branchName\":\"ui-root\"}".utf8)
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
        baseBranchField.typeText("ui-root")
        app.buttons["new-tab-choose-dir-button"].click()
        let createTabButton = app.buttons["new-tab-create-button"]
        waitFor(createTabButton)
        screenshot("new-tab-sheet-filled")
        app.buttons["new-tab-cancel-button"].click()
        waitForDisappear(app.textFields["new-tab-name-field"])
        createTab(named: "Alpha")
        waitFor(app.buttons["tab-button-Alpha"].firstMatch)
        screenshot("main-window-tab")

        app.typeKey("p", modifierFlags: .command)
        let existingWorktreeField = app.textFields["new-pane-name-field"]
        waitFor(existingWorktreeField)
        existingWorktreeField.click()
        existingWorktreeField.typeText("ui-root")
        app.buttons["new-pane-open-button"].click()

        let takeoverCancel = app.buttons["Cancel"].firstMatch
        waitFor(takeoverCancel, timeout: 25)
        screenshot("existing-worktree-prompt")
        app.buttons["Don't Manage"].firstMatch.click()
        let primaryPane = app.staticTexts["pane-name-UITestWorkspace"].firstMatch
        waitFor(primaryPane, timeout: 25)
        let cancelledPaneClose = app.descendants(matching: .any)
            .matching(identifier: "pane-close-UITestWorkspace").firstMatch
        waitFor(cancelledPaneClose, timeout: 10)
        cancelledPaneClose.click()
        waitForDisappear(primaryPane, timeout: 10)

        app.typeKey("p", modifierFlags: .command)
        waitFor(app.textFields["new-pane-name-field"])
        waitFor(app.checkBoxes["new-pane-agent-control-toggle"])
        screenshot("new-pane-sheet")
        screenshot("new-pane-agent-control")
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(app.textFields["new-pane-name-field"], timeout: 25)
        createPane(named: "feature-a")
        createPane(named: "feature-b")
        screenshot("split-panes")

        GitUITestWorkspace.addManagedSecondaryWorktree(
            folder: "wt-cleanup",
            newTrackingBranch: "track-wt-cleanup"
        )
        createPane(named: "wt-cleanup")
        app.descendants(matching: .any)
            .matching(identifier: "pane-close-wt-cleanup").firstMatch.click()
        let keepWorktree = app.buttons["Keep Worktree"].firstMatch
        waitFor(keepWorktree, timeout: 10)
        screenshot("worktree-cleanup-alert")
        app.windows.firstMatch.buttons["Cancel"].firstMatch.click()
        waitForDisappear(keepWorktree)

        createTab(named: "Beta")
        let alphaTab = app.buttons["tab-button-Alpha"].firstMatch
        let betaTab = app.buttons["tab-button-Beta"].firstMatch
        waitFor(alphaTab)
        waitFor(betaTab)
        alphaTab.click(forDuration: 0.5, thenDragTo: betaTab)
        XCTAssertLessThan(betaTab.frame.minX, alphaTab.frame.minX)

        alphaTab.click()
        let firstPane = app.staticTexts["pane-name-feature-a"].firstMatch
        let secondPane = app.staticTexts["pane-name-feature-b"].firstMatch
        waitFor(firstPane)
        waitFor(secondPane)
        firstPane.click(forDuration: 0.5, thenDragTo: secondPane)
        XCTAssertLessThan(secondPane.frame.minX, firstPane.frame.minX)
        screenshot("reordered-tabs-and-panes")

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
        waitForDisappear(shellPicker, timeout: 10)

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

        let panesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-panes").firstMatch
        waitFor(panesTab)
        panesTab.click()
        screenshot("settings-panes")

        let injectionPolicyPicker = settingsWindow.descendants(matching: .any)
            .matching(identifier: "settings-agent-control-injection-policy-picker").firstMatch
        waitFor(injectionPolicyPicker)
        screenshot("settings-agent-control")

        // 7. Settings — Notifications tab
        let notificationsTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-notifications")
            .firstMatch
        waitFor(notificationsTab)
        notificationsTab.click()
        screenshot("settings-notifications")

        let profilesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-profiles").firstMatch
        waitFor(profilesTab)
        profilesTab.click()
        let newProfileButton = app.buttons["New Profile"]
        waitFor(newProfileButton)
        newProfileButton.click()
        let profileNameField = app.textFields["profile-editor-name-field"]
        waitFor(profileNameField)
        profileNameField.click()
        profileNameField.typeText("Docs Profile")
        app.buttons["Save"].click()
        waitFor(app.staticTexts["Docs Profile"])
        screenshot("settings-profiles")

        let toolsTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-tools").firstMatch
        waitFor(toolsTab)
        toolsTab.click()
        screenshot("settings-tools")

        let shortcutsTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-shortcuts").firstMatch
        waitFor(shortcutsTab)
        shortcutsTab.click()
        screenshot("settings-shortcuts")

        let statusLineTab = app.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-status-line").firstMatch
        waitFor(statusLineTab)
        statusLineTab.click()
        screenshot("settings-status-line")

        let debugTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-debug").firstMatch
        waitFor(debugTab)
        debugTab.click()
        screenshot("settings-debug")
        app.typeKey("w", modifierFlags: .command)
        waitForDisappear(settingsWindow)
    }

    private func captureStatusIndicators() {
        createTab(named: "Status")
        createPane(named: "idle-pane")
        waitFor(
            app.descendants(matching: .any)
                .matching(identifier: "pane-activity-idle-idle-pane").firstMatch,
            timeout: 15
        )
        waitFor(app.descendants(matching: .any).matching(identifier: "status-line-row").firstMatch)
        screenshot("pane-status-indicators")

        let shellName = openShellHere(from: "idle-pane")
        app.staticTexts["pane-name-\(shellName)"].firstMatch.click()
        app.typeText("printf '\\a'")
        app.typeKey(.enter, modifierFlags: [])
        app.staticTexts["pane-name-idle-pane"].firstMatch.click()
        let notificationSidebar = app.descendants(matching: .any)
            .matching(identifier: "notification-sidebar").firstMatch
        waitFor(notificationSidebar, timeout: 10)
        screenshot("notification-sidebar")
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

    func testTraceDashboard() {
        // 1. Enable Debug mode
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

        // 2. Create a tab and pane to generate real trace data
        createTab(named: "trace-demo")
        createPane(named: "worker")

        // 3. Open the trace dashboard
        app.typeKey("d", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Trace Dashboard"]
        waitFor(dashboard)
        XCTAssertEqual(round(dashboard.frame.width), 900)
        XCTAssertEqual(round(dashboard.frame.height), 664)

        // 4. Refresh so the dashboard reads the per-pane files written during step 2
        let refreshButton = dashboard.buttons["trace-dashboard-refresh-button"]
        waitFor(refreshButton)
        refreshButton.click()

        // 5. Select the first pane row so the detail view loads
        let paneRow = dashboard.descendants(matching: .any)
            .matching(identifier: "trace-dashboard-pane-row").firstMatch
        waitFor(paneRow, timeout: 10)
        paneRow.click()
        XCTAssertTrue(paneRow.isSelected)

        // 6. Wait for the per-pane trace list to appear
        let filterField = dashboard.textFields["trace-dashboard-filter-field"]
        waitFor(filterField, timeout: 10)

        screenshot("trace-dashboard")

        // 7. Click the first trace row to open the waterfall
        let traceRow = dashboard.descendants(matching: .any)
            .matching(identifier: "trace-dashboard-list-row").firstMatch
        waitFor(traceRow, timeout: 10)
        traceRow.click()

        // 8. Wait for the waterfall to render
        let waterfall = dashboard.descendants(matching: .any)
            .matching(identifier: "trace-dashboard-waterfall").firstMatch
        waitFor(waterfall, timeout: 10)

        screenshot("trace-waterfall")
    }

    func testInvariantDashboardScreenshot() throws {
        // 1. Enable Debug mode
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

        // 2. Create a real Claude pane and find the monitor file created for it
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
        createPane(named: "worker")

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

        // 3. Open the dashboard, then exercise the same file ingress Claude uses.
        app.typeKey("i", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Invariant Dashboard"]
        waitFor(dashboard)
        XCTAssertEqual(round(dashboard.frame.width), 900)
        XCTAssertEqual(round(dashboard.frame.height), 664)
        let refreshButton = dashboard.buttons["invariant-dashboard-refresh-button"]
        waitFor(refreshButton)
        try Data(#"{"worktree":{"name":"wrong-name","branch":"main"}}"#.utf8)
            .write(to: XCTUnwrap(monitorFile))

        let violation = dashboard.staticTexts["statusline.worktree.name"]
        let violationDeadline = Date().addingTimeInterval(10)
        repeat {
            refreshButton.click()
            if violation.exists { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < violationDeadline
        XCTAssertTrue(violation.exists, "Expected the real worktree-name violation to appear")
        let violationRow = dashboard.descendants(matching: .any)
            .matching(identifier: "invariant-dashboard-row").firstMatch
        waitFor(violationRow, timeout: 10)

        screenshot("invariant-dashboard")
    }
}
