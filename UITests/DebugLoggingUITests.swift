import XCTest

final class DebugLoggingUITests: BaseTestCase {

    func testDebugToggleExistsInGeneralTab() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-debug-logging-toggle"]
        waitFor(toggle)
        XCTAssertTrue(toggle.exists)
    }

    func testDebugToggleDefaultsToOff() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-debug-logging-toggle"]
        waitFor(toggle)
        XCTAssertEqual(toggle.value as? Int, 0)
    }

    func testDebugButtonHiddenWhenDisabled() {
        let button = app.buttons["debug-log-button"]
        XCTAssertFalse(button.waitForExistence(timeout: 1))
    }

    func testDebugButtonVisibleWhenEnabled() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-debug-logging-toggle"]
        waitFor(toggle)
        toggle.click()

        app.typeKey("w", modifierFlags: .command)

        let button = app.buttons["debug-log-button"]
        waitFor(button)
        XCTAssertTrue(button.exists)
    }

    func testDebugLogSheetOpens() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-debug-logging-toggle"]
        waitFor(toggle)
        toggle.click()

        app.typeKey("w", modifierFlags: .command)

        let debugButton = app.buttons["debug-log-button"]
        waitFor(debugButton)
        debugButton.click()

        let closeButton = app.buttons["debug-log-close-button"]
        waitFor(closeButton)
        XCTAssertTrue(closeButton.exists)
    }

    func testDebugLogEmptyState() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-debug-logging-toggle"]
        waitFor(toggle)
        toggle.click()

        app.typeKey("w", modifierFlags: .command)

        let debugButton = app.buttons["debug-log-button"]
        waitFor(debugButton)
        debugButton.click()

        let emptyState = app.staticTexts["debug-log-empty-state"]
        waitFor(emptyState)
        XCTAssertTrue(emptyState.exists)

        let closeButton = app.buttons["debug-log-close-button"]
        closeButton.click()

        waitForDisappear(closeButton)
    }

    func testDebugLogCopyButtonDisabledWhenEmpty() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-debug-logging-toggle"]
        waitFor(toggle)
        toggle.click()

        app.typeKey("w", modifierFlags: .command)

        let debugButton = app.buttons["debug-log-button"]
        waitFor(debugButton)
        debugButton.click()

        let copyButton = app.buttons["debug-log-copy-button"]
        waitFor(copyButton)
        XCTAssertFalse(copyButton.isEnabled)

        let closeButton = app.buttons["debug-log-close-button"]
        closeButton.click()
    }

    func testDebugLogClearButtonDisabledWhenEmpty() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-debug-logging-toggle"]
        waitFor(toggle)
        toggle.click()

        app.typeKey("w", modifierFlags: .command)

        let debugButton = app.buttons["debug-log-button"]
        waitFor(debugButton)
        debugButton.click()

        let clearButton = app.buttons["debug-log-clear-button"]
        waitFor(clearButton)
        XCTAssertFalse(clearButton.isEnabled)

        let closeButton = app.buttons["debug-log-close-button"]
        closeButton.click()
    }

    func testDebugLogCloseDismissesSheet() {
        openSettings()
        let generalTab = app.buttons["General"]
        waitFor(generalTab)
        generalTab.click()

        let toggle = app.checkBoxes["settings-debug-logging-toggle"]
        waitFor(toggle)
        toggle.click()

        app.typeKey("w", modifierFlags: .command)

        let debugButton = app.buttons["debug-log-button"]
        waitFor(debugButton)
        debugButton.click()

        let closeButton = app.buttons["debug-log-close-button"]
        waitFor(closeButton)
        closeButton.click()

        waitForDisappear(closeButton)
    }

    private func openSettings() {
        app.typeKey(",", modifierFlags: .command)
    }
}
