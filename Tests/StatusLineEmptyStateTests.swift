import XCTest

@testable import AgentSessionManager

@MainActor
final class StatusLineEmptyStateTests: XCTestCase {
    func testNewMonitorHasNilCurrentData() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        XCTAssertNil(monitor.currentData)
    }

    func testDefaultConfigHasNonEmptyRows() {
        let config = StatusLineConfig()
        let nonEmptyRows = config.rows.filter { !$0.items.isEmpty }
        XCTAssertFalse(
            nonEmptyRows.isEmpty,
            "Default config must have at least one non-empty row so the status line renders in empty state")
    }

    func testEmptyConfigProducesNoRows() {
        var config = StatusLineConfig()
        config.rows = []
        let nonEmptyRows = config.rows.filter { !$0.items.isEmpty }
        XCTAssertTrue(nonEmptyRows.isEmpty, "Config with no rows should produce no non-empty rows")
    }
}
