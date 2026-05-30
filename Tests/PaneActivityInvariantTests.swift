import XCTest

@testable import AgentSessionManager

@MainActor
final class PaneActivityInvariantTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TracingService.shared.enableTestCapture()
    }

    override func tearDown() {
        super.tearDown()
        TracingService.shared.resetForTesting()
    }

    // MARK: - paneActivityState derivation

    func testWaitingWhenHasNotification() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isProducingOutput: true,
            sessionState: "busy",
            hasNotification: true
        )
        XCTAssertEqual(state, .waiting)
    }

    func testWaitingBeatsBusyAndOutput() {
        XCTAssertEqual(
            paneActivityState(
                processState: .running(pid: 1),
                isProducingOutput: true,
                sessionState: "busy",
                hasNotification: true
            ),
            .waiting
        )
    }

    func testWorkingWhenRunningAndProducingOutput() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isProducingOutput: true,
            sessionState: nil,
            hasNotification: false
        )
        XCTAssertEqual(state, .working)
    }

    func testWorkingWhenRunningAndSessionBusy() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isProducingOutput: false,
            sessionState: "busy",
            hasNotification: false
        )
        XCTAssertEqual(state, .working)
    }

    func testWorkingWhenRunningAndSessionRetry() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isProducingOutput: false,
            sessionState: "retry",
            hasNotification: false
        )
        XCTAssertEqual(state, .working)
    }

    func testIdleWhenRunningButQuiet() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isProducingOutput: false,
            sessionState: nil,
            hasNotification: false
        )
        XCTAssertEqual(state, .idle)
    }

    func testIdleWhenExited() {
        let state = paneActivityState(
            processState: .exited(code: 0),
            isProducingOutput: false,
            sessionState: nil,
            hasNotification: false
        )
        XCTAssertEqual(state, .idle)
    }

    func testIdleWhenExitedRegardlessOfStaleOutput() {
        let state = paneActivityState(
            processState: .exited(code: 0),
            isProducingOutput: true,
            sessionState: "busy",
            hasNotification: false
        )
        XCTAssertEqual(state, .idle)
    }

    func testIdleWhenProcessNil() {
        let state = paneActivityState(
            processState: nil,
            isProducingOutput: false,
            sessionState: nil,
            hasNotification: false
        )
        XCTAssertEqual(state, .idle)
    }

    // MARK: - PR separation invariant

    func testPRSignalsAbsentFromSignature() {
        // paneActivityState takes no pr/isMerged parameter — PR cannot influence the result.
        // This test documents that invariant structurally.
        let withNotification = paneActivityState(
            processState: .running(pid: 1),
            isProducingOutput: false,
            sessionState: nil,
            hasNotification: true
        )
        let withoutNotification = paneActivityState(
            processState: .running(pid: 1),
            isProducingOutput: false,
            sessionState: nil,
            hasNotification: false
        )
        XCTAssertEqual(withNotification, .waiting)
        XCTAssertEqual(withoutNotification, .idle)
    }

    // MARK: - Waiting ⇔ notification invariants

    func testNoNotificationNeverWaiting() {
        let states: [PaneActivityState] = [
            paneActivityState(
                processState: .running(pid: 1), isProducingOutput: true, sessionState: "busy", hasNotification: false),
            paneActivityState(
                processState: .running(pid: 1), isProducingOutput: false, sessionState: nil, hasNotification: false),
            paneActivityState(
                processState: .exited(code: 0), isProducingOutput: false, sessionState: nil, hasNotification: false),
            paneActivityState(processState: nil, isProducingOutput: false, sessionState: nil, hasNotification: false),
        ]
        for state in states {
            XCTAssertNotEqual(state, .waiting, "Expected non-waiting without notification, got \(state)")
        }
    }

    func testNotificationAlwaysWaiting() {
        let states: [PaneActivityState] = [
            paneActivityState(
                processState: .running(pid: 1), isProducingOutput: true, sessionState: "busy", hasNotification: true),
            paneActivityState(
                processState: .running(pid: 1), isProducingOutput: false, sessionState: nil, hasNotification: true),
            paneActivityState(
                processState: .exited(code: 0), isProducingOutput: false, sessionState: nil, hasNotification: true),
            paneActivityState(processState: nil, isProducingOutput: false, sessionState: nil, hasNotification: true),
        ]
        for state in states {
            XCTAssertEqual(state, .waiting, "Expected waiting with notification, got \(state)")
        }
    }

    // MARK: - tabActivityState aggregation

    func testTabWaitingIfAnyPaneWaiting() {
        let result = tabActivityState([.idle, .working, .waiting])
        XCTAssertEqual(result, .waiting)
    }

    func testTabWorkingIfAnyPaneWorkingNoWaiting() {
        let result = tabActivityState([.idle, .working])
        XCTAssertEqual(result, .working)
    }

    func testTabIdleIfAllIdle() {
        let result = tabActivityState([.idle, .idle])
        XCTAssertEqual(result, .idle)
    }

    func testTabIdleForEmptyPanes() {
        let result = tabActivityState([])
        XCTAssertEqual(result, .idle)
    }

    func testTabWaitingBeatsWorking() {
        XCTAssertEqual(tabActivityState([.working, .waiting]), .waiting)
    }

    // MARK: - Edge-once tracing invariants

    func testOutputStartedFiredOnceOnRisingEdge() {
        let controller = TerminalController()
        controller.noteOutput()
        let events = TracingService.shared.recordedEventsForTesting
        let started = events.filter { $0.name == "pane.activity.output_started" }
        XCTAssertEqual(started.count, 1)
    }

    func testOutputStartedNotFiredAgainWhileStillProducing() {
        let controller = TerminalController()
        controller.noteOutput()
        controller.noteOutput()
        controller.noteOutput()
        let events = TracingService.shared.recordedEventsForTesting
        let started = events.filter { $0.name == "pane.activity.output_started" }
        XCTAssertEqual(started.count, 1, "output_started must only fire on the rising edge")
    }

    // MARK: - clearNotification trace

    func testClearNotificationEmitsTrace() {
        let appState = AppState()
        let paneID = UUID()
        let tabID = UUID()
        appState.notifications.append(
            PaneNotification(
                paneID: paneID,
                paneName: "test-pane",
                tabID: tabID,
                tabName: "TestTab",
                isPriority: false
            ))
        appState.clearNotification(paneID: paneID)
        let events = TracingService.shared.recordedEventsForTesting
        let cleared = events.first { $0.name == "pane.notification.cleared" }
        XCTAssertNotNil(cleared)
        XCTAssertEqual(cleared?.attributes["reason"], "cleared")
        XCTAssertEqual(cleared?.attributes["pane.name"], "test-pane")
    }
}
