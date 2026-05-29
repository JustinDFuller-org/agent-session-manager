import XCTest

@testable import AgentSessionManager

@MainActor
final class StatusLineMonitorTracingTests: XCTestCase {
    private var appSettings: AppSettings!

    override func setUp() async throws {
        try await super.setUp()
        appSettings = AppSettings()
        appSettings.tracingEnabled = true
        TracingService.shared.configure(from: appSettings)
        TracingService.shared.enableTestCapture()
    }

    override func tearDown() async throws {
        appSettings.tracingEnabled = false
        TracingService.shared.configure(from: appSettings)
        TracingService.shared.resetForTesting()
        try await super.tearDown()
    }

    func testStartedSpanContainsPaneIdTabIdAndHumanReadablePaneName() {
        let paneID = UUID()
        let tabID = UUID()
        let monitor = StatusLineMonitor(
            paneID: paneID,
            paneName: "my-feature-branch",
            cliType: .claude,
            tabID: tabID,
            tabName: "work-tab"
        )
        monitor.start()
        monitor.stop()

        let started = TracingService.shared.recordedEventsForTesting
            .first { $0.name == "statusline.monitor.started" }
        XCTAssertNotNil(started)
        XCTAssertEqual(started?.attributes["pane.name"], "my-feature-branch")
        XCTAssertEqual(started?.attributes["pane.id"], paneID.uuidString)
        XCTAssertEqual(started?.attributes["tab.id"], tabID.uuidString)
        XCTAssertEqual(started?.attributes["tab.name"], "work-tab")
    }

    func testStoppedSpanContainsPaneIdAndTabId() {
        let paneID = UUID()
        let tabID = UUID()
        let monitor = StatusLineMonitor(
            paneID: paneID,
            paneName: "stop-test-pane",
            cliType: .claude,
            tabID: tabID,
            tabName: "stop-test-tab"
        )
        monitor.start()
        monitor.stop()

        let stopped = TracingService.shared.recordedEventsForTesting
            .first { $0.name == "statusline.monitor.stopped" }
        XCTAssertNotNil(stopped)
        XCTAssertEqual(stopped?.attributes["pane.name"], "stop-test-pane")
        XCTAssertEqual(stopped?.attributes["pane.id"], paneID.uuidString)
        XCTAssertEqual(stopped?.attributes["tab.id"], tabID.uuidString)
    }

    func testPaneNameFallsBackToUUIDPrefixWhenEmpty() {
        let paneID = UUID()
        let monitor = StatusLineMonitor(
            paneID: paneID,
            paneName: "",
            cliType: .claude
        )
        monitor.start()
        monitor.stop()

        let started = TracingService.shared.recordedEventsForTesting
            .first { $0.name == "statusline.monitor.started" }
        XCTAssertEqual(started?.attributes["pane.name"], String(paneID.uuidString.prefix(8)))
    }
}
