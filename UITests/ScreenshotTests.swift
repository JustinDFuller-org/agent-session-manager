import XCTest

final class ScreenshotTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        try? Data("\"head\"".utf8).write(to: UITestAppSupport.directory.appending(path: "worktree-base-ref.json"))
    }

    func testWalkthrough() {
        // 1. Empty state
        waitFor(emptyStateHint)
        screenshot("empty-state")

        // 2. New tab sheet — empty, then filled
        app.typeKey("t", modifierFlags: .command)
        waitFor(app.textFields["new-tab-name-field"])
        screenshot("new-tab-sheet")
        app.textFields["new-tab-name-field"].typeText("Alpha")
        let dirField = app.textFields["new-tab-directory-field"]
        waitFor(dirField)
        dirField.click()
        dirField.typeText(GitUITestWorkspace.directoryURL.path)
        screenshot("new-tab-sheet-filled")
        let createBtn = app.buttons["new-tab-create-button"]
        waitFor(createBtn)
        createBtn.click()
        waitFor(app.buttons["tab-button-Alpha"].firstMatch)

        // 3. Main window with a tab
        screenshot("main-window-tab")

        // 4. New pane sheet open
        app.typeKey("p", modifierFlags: .command)
        waitFor(app.textFields["new-pane-name-field"])
        screenshot("new-pane-sheet")
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(app.textFields["new-pane-name-field"])

        // 5. Split panes
        createPane(named: "feature-a")
        screenshot("split-panes")

        // 6. Settings — Panes tab
        app.typeKey(",", modifierFlags: .command)
        let panesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-panes").firstMatch
        waitFor(panesTab)
        panesTab.click()
        screenshot("settings-panes")

        // 7. Settings — Notifications tab
        let notificationsTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-notifications")
            .firstMatch
        waitFor(notificationsTab)
        notificationsTab.click()
        screenshot("settings-notifications")

        // 8. Remaining settings tabs — click then screenshot each individually so that
        //    literal string arguments are visible to the scripts/ship.sh grep invariant.
        let profilesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-profiles").firstMatch
        waitFor(profilesTab)
        profilesTab.click()
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

        // 4. Refresh so the dashboard reads the per-pane files written during step 2
        let refreshButton = dashboard.buttons["trace-dashboard-refresh-button"]
        waitFor(refreshButton)
        refreshButton.click()

        // 5. Select the first pane row so the detail view loads
        let paneRow = dashboard.descendants(matching: .any)
            .matching(identifier: "trace-dashboard-pane-row").firstMatch
        waitFor(paneRow, timeout: 10)
        paneRow.click()

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

    func testInvariantDashboard() {
        // Create a tab so invariants have some context to display
        createTab(named: "invariant-demo")

        // Open the invariant dashboard
        app.typeKey("i", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Invariant Dashboard"]
        waitFor(dashboard)

        // Wait for the table to settle (refresh or empty state appears)
        let table = dashboard.descendants(matching: .any)
            .matching(identifier: "invariant-dashboard-table").firstMatch
        waitFor(table, timeout: 10)

        screenshot("invariant-dashboard")
    }

    // MARK: - Real-agent tests (require RUN_REAL_AGENT_TESTS=1)

    func testActivityIndicatorStates() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_REAL_AGENT_TESTS"] == "1",
            "Set RUN_REAL_AGENT_TESTS=1 to run real-agent tests (requires claude CLI)"
        )

        createTab(named: "indicators")

        // Pane 1: claude with no prompt yet — stays idle while waiting for user input
        createPane(named: "idle")

        // Pane 2: claude with a long prompt — enters working state while processing
        createPane(named: "working")
        // Terminal is focused after pane creation; submit a complex prompt
        let workingPane = app.descendants(matching: .any)
            .matching(identifier: "pane-working").firstMatch
        waitFor(workingPane)
        workingPane.click()
        let longPrompt =
            "Describe in exhaustive detail the history and mathematical foundations of RSA encryption, "
            + "covering all security properties, implementation considerations, and real-world usage.\n"
        app.typeText(longPrompt)

        // Pane 3: claude with a short prompt — completes quickly, rings bell → waiting state
        createPane(named: "plan")
        let planPane = app.descendants(matching: .any)
            .matching(identifier: "pane-plan").firstMatch
        waitFor(planPane)
        planPane.click()
        app.typeText("Say hello in exactly one word.\n")

        // Wait for the bell notification on pane "plan" (activity state → waiting)
        waitForActivityState("waiting", paneName: "plan", timeout: 120)

        screenshot("activity-indicator-states")
    }

    func testPRMergedNotifications() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_REAL_AGENT_TESTS"] == "1",
            "Set RUN_REAL_AGENT_TESTS=1 to run real-agent tests (requires gh CLI and network)"
        )

        // Terminate the app launched in setUp, then reconfigure and relaunch.
        // sessions.json pre-configures a pane on the merged PR branch so that
        // checkForMergedPRsAfterRestore fires the notification immediately on startup.
        app.terminate()

        let prRepo = GitUITestWorkspace.setupPRDetectionRepo()
        writePRDetectionSession(repoURL: prRepo, paneName: "pr-pane")
        writePRPollingSettings()

        app = XCUIApplication()
        app.launch()
        app.activate()

        // checkForMergedPRsAfterRestore runs at startup — wait for the notification
        let notifRow = app.descendants(matching: .any)
            .matching(identifier: "notification-row-pr-pane").firstMatch
        waitFor(notifRow, timeout: 60)

        // 1. Pane shows waiting indicator (PR merged notification pending)
        screenshot("pane-status-indicators")

        // 2. Notification sidebar shows the PR merged entry
        screenshot("notification-sidebar")

        // 3. Click the notification row → prMergedActionRequested → PR Merged alert
        notifRow.click()
        let alert = app.alerts["PR Merged"]
        waitFor(alert, timeout: 5)
        screenshot("pr-merged-alert")

        // Dismiss alert so tearDown can cleanly terminate the app
        alert.buttons["Cancel"].click()
    }
}
