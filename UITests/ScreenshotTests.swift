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
        screenshot("new-tab-sheet-filled")
        app.buttons["new-tab-choose-dir-button"].click()
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

        let tracingTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-tracing").firstMatch
        waitFor(tracingTab)
        tracingTab.click()
        screenshot("settings-tracing")

        app.typeKey("w", modifierFlags: .command)
    }

    func testTraceDashboard() {
        // 1. Enable tracing
        app.typeKey(",", modifierFlags: .command)
        let tracingTab = app.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-tracing").firstMatch
        waitFor(tracingTab)
        tracingTab.click()
        let tracingToggle = app.checkBoxes["settings-tracing-enabled-toggle"]
        waitFor(tracingToggle)
        if tracingToggle.value as? Int == 0 {
            tracingToggle.click()
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
    }
}
