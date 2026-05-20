import XCTest

final class NotificationUITests: BaseTestCase {
    /// Regression: General (debug) and Notifications (banner) settings must both remain reachable after merging those features.
    func testGeneralDebugToggleAndNotificationsBannerToggleBothExist() {
        app.typeKey(",", modifierFlags: .command)

        let generalTab = app.buttons["General"]
        waitFor(generalTab, timeout: 3)
        generalTab.click()
        waitFor(app.checkBoxes["settings-debug-logging-toggle"], timeout: 3)

        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab, timeout: 3)
        notificationsTab.click()
        waitFor(app.checkBoxes["settings-macos-banner-notifications-toggle"], timeout: 3)
    }

    func testNotificationsTabVisibleInSettings() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab, timeout: 3)
    }

    func testNotificationsSettingsControlsVisible() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab, timeout: 3)
        notificationsTab.click()

        let sidebarSide = app.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-side")
            .firstMatch
        waitFor(sidebarSide, timeout: 3)

        let priorityToggle = app.checkBoxes["settings-priority-notifications-toggle"]
        waitFor(priorityToggle, timeout: 3)

        let bannerToggle = app.checkBoxes["settings-macos-banner-notifications-toggle"]
        waitFor(bannerToggle, timeout: 3)
    }

    func testPriorityToggleAppearsInNewPaneSheetWhenEnabled() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab, timeout: 3)
        notificationsTab.click()

        let priorityToggle = app.checkBoxes["settings-priority-notifications-toggle"]
        waitFor(priorityToggle, timeout: 3)
        if priorityToggle.value as? Int == 0 {
            priorityToggle.click()
        }

        let settingsWindow = app.windows.element(boundBy: 1)
        settingsWindow.typeKey("w", modifierFlags: .command)

        createTab(named: "PriorityTab")
        app.typeKey("p", modifierFlags: .command)

        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField, timeout: 3)

        let newPanePriorityToggle = app.checkBoxes["new-pane-priority-toggle"]
        XCTAssertTrue(newPanePriorityToggle.waitForExistence(timeout: 3))
    }

    // Regression: notification click (and any other activation path) must not open a second window.
    func testOnlyOneWindowExistsAfterLaunch() {
        let nonPanelWindows = app.windows.allElementsBoundByIndex.filter {
            $0.title != "Notification Center"
        }
        XCTAssertEqual(nonPanelWindows.count, 1, "Expected exactly one app window after launch")
    }

    /// Regression: simulated banner activation (legacy `NSApp.activate` + dedupe) must not leave two main windows.
    func testNotificationClickDoesNotOpenSecondMainWindow() {
        app.terminate()
        app.launchArguments = [
            "--uitesting",
            "--uitesting-skip-restore",
            "--uitesting-simulate-banner-click",
        ]
        app.launch()

        let mainTitle = "Agent Session Manager"
        let predicate = NSPredicate(format: "title CONTAINS %@", mainTitle)
        let mainWindows = app.windows.matching(predicate)
        let oneMain = mainWindows.element(boundBy: 0)
        XCTAssertTrue(oneMain.waitForExistence(timeout: 5))

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if mainWindows.count == 1 { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertEqual(
            mainWindows.count,
            1,
            "Expected exactly one main window after simulated notification activation"
        )
    }

    func testAlwaysShowNotificationsBarToggleExistsAndIsOnByDefault() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab, timeout: 3)
        notificationsTab.click()

        let toggle = app.checkBoxes["settings-always-show-notifications-bar-toggle"]
        waitFor(toggle, timeout: 3)
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? Int, 1)
    }

    func testAlwaysShowNotificationsBarToggleCanBeToggledOffAndOn() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab, timeout: 3)
        notificationsTab.click()

        let toggle = app.checkBoxes["settings-always-show-notifications-bar-toggle"]
        waitFor(toggle, timeout: 3)

        if toggle.value as? Int == 1 {
            toggle.click()
        }
        XCTAssertEqual(toggle.value as? Int, 0)

        toggle.click()
        XCTAssertEqual(toggle.value as? Int, 1)
    }

    func testStickyNotificationsToggleAppearsInSettings() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab, timeout: 3)
        notificationsTab.click()

        let toggle = app.checkBoxes["settings-sticky-notifications-toggle"]
        waitFor(toggle, timeout: 3)
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? Int, 0)
    }

    func testStickyNotificationsToggleCanBeToggled() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab, timeout: 3)
        notificationsTab.click()

        let toggle = app.checkBoxes["settings-sticky-notifications-toggle"]
        waitFor(toggle, timeout: 3)

        if toggle.value as? Int == 1 {
            toggle.click()
        }
        XCTAssertEqual(toggle.value as? Int, 0)

        toggle.click()
        XCTAssertEqual(toggle.value as? Int, 1)
    }

    func testPriorityToggleHiddenInNewPaneSheetWhenDisabled() {
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        waitFor(notificationsTab, timeout: 3)
        notificationsTab.click()

        let priorityToggle = app.checkBoxes["settings-priority-notifications-toggle"]
        waitFor(priorityToggle, timeout: 3)
        if priorityToggle.value as? Int == 1 {
            priorityToggle.click()
        }

        let settingsWindow = app.windows.element(boundBy: 1)
        settingsWindow.typeKey("w", modifierFlags: .command)

        createTab(named: "NonPriorityTab")
        app.typeKey("p", modifierFlags: .command)

        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField, timeout: 3)

        let newPanePriorityToggle = app.checkBoxes["new-pane-priority-toggle"]
        XCTAssertFalse(newPanePriorityToggle.exists)
    }
}
