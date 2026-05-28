import XCTest

final class SettingsFlowTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        let file = UITestAppSupport.directory.appending(path: "default-branch.json")
        try? FileManager.default.removeItem(at: file)
    }

    override func tearDown() {
        let file = UITestAppSupport.directory.appending(path: "default-branch.json")
        try? FileManager.default.removeItem(at: file)
        super.tearDown()
    }

    func testSettingsFlow() {
        // ── General tab ──────────────────────────────────────────────────────
        app.typeKey(",", modifierFlags: .command)
        let generalTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-general").firstMatch
        waitFor(generalTab)
        generalTab.click()

        // Default branch field exists and shows the value from BaseTestCase setup ("ui-root")
        let branchField = app.textFields["settings-default-branch-field"]
        waitFor(branchField)
        XCTAssertTrue(branchField.exists)
        XCTAssertEqual(branchField.value as? String, "ui-root")

        // Field accepts input
        branchField.click()
        branchField.typeKey("a", modifierFlags: .command)
        branchField.typeText("develop")
        XCTAssertEqual(branchField.value as? String, "develop")

        // Toggle hides then restores the field
        let branchToggle = app.checkBoxes["settings-default-branch-toggle"]
        waitFor(branchToggle)
        branchToggle.click()
        XCTAssertFalse(app.textFields["settings-default-branch-field"].waitForExistence(timeout: 0.5))
        branchToggle.click()
        waitFor(app.textFields["settings-default-branch-field"])

        // Continue-on-restart toggle exists and defaults to on
        let continueToggle = app.checkBoxes["settings-continue-on-restart-toggle"]
        waitFor(continueToggle)
        XCTAssertTrue(continueToggle.exists)
        XCTAssertEqual(continueToggle.value as? Int, 1)

        // Auto session name toggle exists
        let autoSessionNameToggle = app.checkBoxes["settings-auto-session-name-toggle"]
        waitFor(autoSessionNameToggle)
        XCTAssertTrue(autoSessionNameToggle.exists)

        // Shell picker is in General (not CLI Tools)
        let shellPicker = app.descendants(matching: .any).matching(identifier: "settings-shell-picker").firstMatch
        waitFor(shellPicker)
        XCTAssertTrue(shellPicker.exists, "Shell picker should exist under General tab")

        // ── Notifications tab ────────────────────────────────────────────────
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-notifications")
            .firstMatch
        waitFor(notificationsTab)
        notificationsTab.click()

        // Regression: banner toggle and open-notification-settings button are reachable
        let bannerToggle = app.checkBoxes["settings-macos-banner-notifications-toggle"]
        waitFor(bannerToggle)

        let openNotifSettingsButton = app.buttons["settings-open-notification-settings-button"]
        XCTAssertTrue(openNotifSettingsButton.exists)

        let stickyToggle = app.checkBoxes["settings-sticky-notifications-toggle"]
        XCTAssertFalse(stickyToggle.exists)

        let alwaysShowToggle = app.checkBoxes["settings-always-show-notifications-bar-toggle"]
        waitFor(alwaysShowToggle)
        XCTAssertEqual(alwaysShowToggle.value as? Int, 1)

        let priorityToggle = app.checkBoxes["settings-priority-notifications-toggle"]
        waitFor(priorityToggle)
        XCTAssertTrue(priorityToggle.exists)

        let sidebarSide = app.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-side")
            .firstMatch
        waitFor(sidebarSide)

        // ── Shortcuts tab ────────────────────────────────────────────────────
        let shortcutsTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-shortcuts").firstMatch
        waitFor(shortcutsTab)
        shortcutsTab.click()

        let closeTabShortcut = app.staticTexts["Close Active Tab"]
        waitFor(closeTabShortcut)
        XCTAssertTrue(closeTabShortcut.exists)

        // ── Status Line tab ──────────────────────────────────────────────────
        let statusLineTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-status-line")
            .firstMatch
        waitFor(statusLineTab)
        statusLineTab.click()

        let prTrackingToggle = app.checkBoxes["settings-pr-tracking-toggle"]
        waitFor(prTrackingToggle)
        XCTAssertEqual(prTrackingToggle.value as? Int, 1)
        prTrackingToggle.click()
        XCTAssertEqual(prTrackingToggle.value as? Int, 0)
        prTrackingToggle.click()
        XCTAssertEqual(prTrackingToggle.value as? Int, 1)

        // ── Worktrees tab ────────────────────────────────────────────────────
        let worktreesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-worktrees").firstMatch
        waitFor(worktreesTab)
        worktreesTab.click()

        // SwiftUI Picker with .pickerStyle(.segmented) may not appear as SegmentedControl in XCTest.
        // Query the containing element to verify it exists, then interact with its buttons from app scope.
        let baseRefPicker = app.descendants(matching: .any).matching(identifier: "settings-worktree-base-ref-picker")
            .firstMatch
        waitFor(baseRefPicker)
        XCTAssertTrue(baseRefPicker.exists)

        // Segmented picker segments may appear as radio buttons or other types, not just AXButton.
        let freshButton = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Fresh'")).firstMatch
        waitFor(freshButton)

        let headButton = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'HEAD'")).firstMatch
        waitFor(headButton)
        headButton.click()
        // Verify Fresh is no longer selected and HEAD is selected
        XCTAssertEqual(freshButton.value as? Int, 0)
        XCTAssertEqual(headButton.value as? Int, 1)

        // ── Profiles tab ─────────────────────────────────────────────────────
        let profilesTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-profiles").firstMatch
        waitFor(profilesTab)
        profilesTab.click()

        createProfile(named: "Alpha")
        createProfile(named: "Beta")

        let moveDownButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'profile-move-down-'")
        )
        XCTAssertGreaterThan(moveDownButtons.count, 0)

        let moveUpButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'profile-move-up-'")
        )
        XCTAssertGreaterThan(moveUpButtons.count, 0)

        let profileNames = app.staticTexts.matching(
            NSPredicate(format: "value == 'Alpha' OR value == 'Beta'")
        )
        let nameBefore = profileNames.firstMatch.value as? String
        moveDownButtons.firstMatch.click()
        let nameAfter = profileNames.firstMatch.value as? String
        XCTAssertNotEqual(nameBefore, nameAfter, "Profile order should swap after move-down")

        verifyTracingAndDashboard()
    }

    func testCLIToolsEnableRevealsOptions() {
        app.typeKey(",", modifierFlags: .command)

        let toolsTab = app.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-tools").firstMatch
        waitFor(toolsTab)
        toolsTab.click()

        // Shell picker and detect button must not appear in CLI Tools
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "settings-shell-picker").firstMatch
                .waitForExistence(timeout: 1),
            "Shell picker should not exist under CLI Tools tab"
        )
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "settings-detect-tools-button").firstMatch
                .waitForExistence(timeout: 1),
            "Detect Installed Tools button should not exist anywhere in Settings"
        )

        // All four CLIs should appear in the picker regardless of enabled state
        let codexSegment = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Codex'")).firstMatch
        waitFor(codexSegment)
        codexSegment.click()

        // Codex is disabled by default — enable toggle should be off, options hidden
        let codexEnableToggle = app.checkBoxes["settings-tool-enable-toggle-codex"]
        waitFor(codexEnableToggle)
        XCTAssertEqual(codexEnableToggle.value as? Int, 0, "Codex enable toggle should be off by default")

        XCTAssertFalse(
            app.staticTexts["Not Enabled"].waitForExistence(timeout: 1),
            "Option sections should not appear while Codex is disabled"
        )

        // Enable Codex — option sections should appear
        codexEnableToggle.click()
        XCTAssertEqual(codexEnableToggle.value as? Int, 1, "Codex enable toggle should be on after click")

        let notEnabledSection = app.staticTexts["Not Enabled"]
        waitFor(notEnabledSection)
        XCTAssertTrue(notEnabledSection.exists, "Option sections should appear after enabling Codex")

        // Disable Codex again — options should disappear
        codexEnableToggle.click()
        XCTAssertEqual(codexEnableToggle.value as? Int, 0, "Codex enable toggle should be off after second click")

        XCTAssertFalse(
            app.staticTexts["Not Enabled"].waitForExistence(timeout: 1),
            "Option sections should disappear after disabling Codex"
        )
    }

    private func verifyTracingAndDashboard() {
        // ── Tracing tab ──────────────────────────────────────────────────────
        let tracingTab = app.descendants(matching: .any).matching(identifier: "settings-sidebar-tracing").firstMatch
        waitFor(tracingTab)
        tracingTab.click()

        let tracingToggle = app.checkBoxes["settings-tracing-enabled-toggle"]
        waitFor(tracingToggle)
        if tracingToggle.value as? Int == 0 {
            tracingToggle.click()
        }

        let maxSpansField = app.textFields["settings-tracing-dashboard-max-spans-field"]
        waitFor(maxSpansField)
        XCTAssertTrue(maxSpansField.exists)

        app.typeKey("w", modifierFlags: .command)

        // ── Trace Dashboard window ───────────────────────────────────────────
        app.typeKey("d", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Trace Dashboard"]
        waitFor(dashboard)

        let filterField = dashboard.textFields["trace-dashboard-filter-field"]
        waitFor(filterField)
        XCTAssertTrue(filterField.exists)

        let clearButton = dashboard.buttons["trace-dashboard-clear-button"]
        waitFor(clearButton)
        XCTAssertTrue(clearButton.isEnabled)

        let spanCount = dashboard.staticTexts["trace-dashboard-span-count"]
        waitFor(spanCount)
        XCTAssertTrue(spanCount.exists)
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
}
