import XCTest

@testable import AgentSessionManager

@MainActor
final class AuxiliaryWindowRegistryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
        AuxiliaryWindowRegistry.resetForTesting()
    }

    override func tearDown() {
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
        AuxiliaryWindowRegistry.resetForTesting()
        super.tearDown()
    }

    func testNoWindowsPasses() {
        InvariantReporter.shared.enableTestCapture()

        XCTAssertTrue(AuxiliaryWindowRegistry.check(openTitles: [], requestedIDs: []))
        XCTAssertTrue(InvariantReporter.shared.violationsForTesting.isEmpty)
    }

    func testMainWindowOnlyPasses() {
        InvariantReporter.shared.enableTestCapture()

        XCTAssertTrue(
            AuxiliaryWindowRegistry.check(openTitles: ["Agent Session Manager (Dev)"], requestedIDs: []))
        XCTAssertTrue(InvariantReporter.shared.violationsForTesting.isEmpty)
    }

    func testDashboardOpenWithoutRequestReportsViolationWithWindowTitle() {
        InvariantReporter.shared.enableTestCapture()

        XCTAssertFalse(
            AuxiliaryWindowRegistry.check(openTitles: ["Trace Dashboard"], requestedIDs: []))
        let violation = InvariantReporter.shared.violationsForTesting.first
        XCTAssertEqual(violation?.invariantID, "app.launch.auxiliary_windows_closed")
        XCTAssertEqual(violation?.context["window.title"], "Trace Dashboard")
        XCTAssertEqual(violation?.context["window.id"], "trace-dashboard")
    }

    func testDashboardOpenAfterMatchingRequestPasses() {
        InvariantReporter.shared.enableTestCapture()

        XCTAssertTrue(
            AuxiliaryWindowRegistry.check(
                openTitles: ["Invariant Dashboard"], requestedIDs: ["invariant-dashboard"]))
        XCTAssertTrue(InvariantReporter.shared.violationsForTesting.isEmpty)
    }

    func testTwoUnrequestedDashboardsOpenAtOnceReportsTwoViolations() {
        InvariantReporter.shared.enableTestCapture()

        XCTAssertFalse(
            AuxiliaryWindowRegistry.check(
                openTitles: ["Trace Dashboard", "Invariant Dashboard"], requestedIDs: []))
        let violations = InvariantReporter.shared.violationsForTesting
        XCTAssertEqual(violations.count, 2)
        XCTAssertEqual(Set(violations.map { $0.context["window.id"] }), ["trace-dashboard", "invariant-dashboard"])
    }

    func testCheckOpenWindowsRecordsThatItRan() {
        TracingService.shared.enableTestCapture()

        AuxiliaryWindowRegistry.checkOpenWindows()

        let recorded = TracingService.shared.recordedEventsForTesting.contains {
            $0.name == "app.launch.auxiliary_windows_checked"
        }
        XCTAssertTrue(recorded, "checkOpenWindows() must record that it ran, even on a quiet launch")
    }
}
