import XCTest

final class EmptyStateFlowTests: BaseTestCase {
    func testEmptyStateFlow() {
        waitFor(emptyStateHint)
        XCTAssertEqual(emptyStateHint.value as? String, "Press ⌘T to create a tab")
        screenshot("01-empty-state")

        let nonPanelWindows = app.windows.allElementsBoundByIndex.filter {
            $0.title != "Notification Center"
        }
        XCTAssertEqual(nonPanelWindows.count, 1, "Expected exactly one app window after launch")

        app.menuBars.menuBarItems["File"].click()
        let newPaneItem = app.menuBars.menuBarItems["File"].menuItems["New Pane in Current Tab"]
        waitFor(newPaneItem)
        XCTAssertFalse(newPaneItem.isEnabled)
        let closeTabItem = app.menuBars.menuBarItems["File"].menuItems["Close Tab"]
        XCTAssertFalse(closeTabItem.isEnabled)
        app.typeKey(.escape, modifierFlags: [])

        app.typeKey("t", modifierFlags: .command)
        let nameField = app.textFields["new-tab-name-field"]
        waitFor(nameField)
        XCTAssertTrue(nameField.isEnabled)
        screenshot("02-new-tab-sheet")

        let requiredHint = app.staticTexts["new-tab-required-hint"]
        XCTAssertTrue(requiredHint.exists)
        XCTAssertFalse(app.buttons["new-tab-create-button"].isEnabled)

        nameField.click()
        nameField.typeText("MyTab")
        app.buttons["new-tab-choose-dir-button"].click()
        let createButton = app.buttons["new-tab-create-button"]
        waitFor(createButton)
        XCTAssertTrue(createButton.isEnabled)
        XCTAssertFalse(app.staticTexts["new-tab-required-hint"].exists)
        screenshot("03-new-tab-filled")

        app.buttons["new-tab-cancel-button"].click()
        waitForDisappear(nameField)
    }

    func testBannerActivationDoesNotOpenSecondMainWindow() {
        app.terminate()
        app.launchArguments = [
            "--uitesting",
            "--uitesting-skip-restore",
            "--uitesting-simulate-banner-click",
        ]
        app.launch()

        let predicate = NSPredicate(format: "title CONTAINS %@", "Agent Session Manager")
        let mainWindows = app.windows.matching(predicate)
        XCTAssertTrue(mainWindows.element(boundBy: 0).waitForExistence(timeout: 5))

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if mainWindows.count == 1 { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertEqual(
            mainWindows.count, 1,
            "Expected exactly one main window after simulated notification activation"
        )
    }
}
