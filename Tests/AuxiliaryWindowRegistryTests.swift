import XCTest

@testable import AgentSessionManager

final class AuxiliaryWindowRegistryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
    }

    override func tearDown() {
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
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
    }

    func testDashboardOpenAfterMatchingRequestPasses() {
        InvariantReporter.shared.enableTestCapture()

        XCTAssertTrue(
            AuxiliaryWindowRegistry.check(
                openTitles: ["Invariant Dashboard"], requestedIDs: ["invariant-dashboard"]))
        XCTAssertTrue(InvariantReporter.shared.violationsForTesting.isEmpty)
    }
}
