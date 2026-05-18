import XCTest

final class TraceDashboardUITests: BaseTestCase {

    func testOpenTraceDashboardViaKeyboardShortcut() {
        app.typeKey("d", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Trace Dashboard"]
        waitFor(dashboard)
        XCTAssertTrue(dashboard.exists)
    }

    func testTraceDashboardShowsEmptyStateWhenTracingDisabled() {
        app.typeKey("d", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Trace Dashboard"]
        waitFor(dashboard)

        let emptyState = dashboard.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "No spans captured")
        ).element
        waitFor(emptyState)
        XCTAssertTrue(emptyState.exists)
    }

    func testTraceDashboardHasFilterField() {
        app.typeKey("d", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Trace Dashboard"]
        waitFor(dashboard)

        let filterField = dashboard.textFields["trace-dashboard-filter-field"]
        waitFor(filterField)
        XCTAssertTrue(filterField.exists)
    }

    func testTraceDashboardHasClearButton() {
        app.typeKey("d", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Trace Dashboard"]
        waitFor(dashboard)

        let clearButton = dashboard.buttons["trace-dashboard-clear-button"]
        waitFor(clearButton)
        XCTAssertTrue(clearButton.isEnabled)
    }

    func testTraceDashboardShowsSpanCountLabel() {
        app.typeKey("d", modifierFlags: [.command, .shift])
        let dashboard = app.windows["Trace Dashboard"]
        waitFor(dashboard)

        let spanCount = dashboard.staticTexts["trace-dashboard-span-count"]
        waitFor(spanCount)
        XCTAssertTrue(spanCount.exists)
    }

    func testTraceDashboardMaxSpansFieldExistsInSettings() {
        app.typeKey(",", modifierFlags: .command)

        let tracingTab = app.buttons["Tracing"]
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
    }
}
