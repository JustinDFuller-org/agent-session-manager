import XCTest

final class ScreenshotTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        try? Data("{\"isEnabled\":true,\"branchName\":\"main\"}".utf8)
            .write(to: UITestAppSupport.directory.appending(path: "default-branch.json"))
        try? Data("\"head\"".utf8).write(to: UITestAppSupport.directory.appending(path: "worktree-base-ref.json"))
    }

    func testWalkthrough() {
        // 1. Empty state
        waitFor(emptyStateHint)
        screenshot("empty-state")

        // 2. New tab sheet — empty, then filled (with base branch)
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
        let settingsWindow = app.windows["AgentSessionManager Settings"]
        waitFor(settingsWindow)
        XCTAssertEqual(round(settingsWindow.frame.width), 900)
        XCTAssertEqual(round(settingsWindow.frame.height), 584)
        let panesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-panes").firstMatch
        waitFor(panesTab)
        panesTab.click()
        XCTAssertTrue(panesTab.isSelected)
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
        XCTAssertTrue(debugTab.isSelected)
        screenshot("settings-debug")

        app.typeKey("w", modifierFlags: .command)
    }

    func testPaneStatusIndicatorsScreenshot() {
        createTab(named: "Status")
        createPane(named: "running-pane")

        let idleDot = app.descendants(matching: .any)
            .matching(identifier: "pane-activity-idle-running-pane").firstMatch
        XCTAssertTrue(idleDot.waitForExistence(timeout: 15))
        let statusLineRow = app.descendants(matching: .any)
            .matching(identifier: "status-line-row").firstMatch
        XCTAssertTrue(statusLineRow.waitForExistence(timeout: 5))

        screenshot("pane-status-indicators")
    }

    func testFocusedPaneScreenshot() {
        createTab(named: "Focus")
        createPane(named: "reader")
        createPane(named: "worker")

        let readerHeader = app.descendants(matching: .any).matching(identifier: "pane-header-reader").firstMatch
        waitFor(readerHeader)
        readerHeader.doubleClick()
        waitFor(app.buttons["pane-show-all-reader"].firstMatch)

        screenshot("focused-pane")
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
