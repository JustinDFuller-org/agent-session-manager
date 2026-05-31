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
            isWorking: true,
            sessionState: "busy",
            hasNotification: true
        )
        XCTAssertEqual(state, .waiting)
    }

    func testWaitingBeatsBusyAndExplicitWorkingSignal() {
        XCTAssertEqual(
            paneActivityState(
                processState: .running(pid: 1),
                isWorking: true,
                sessionState: "busy",
                hasNotification: true
            ),
            .waiting
        )
    }

    func testWorkingWhenRunningAndExplicitlyWorking() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isWorking: true,
            sessionState: nil,
            hasNotification: false
        )
        XCTAssertEqual(state, .working)
    }

    func testWorkingWhenRunningAndSessionBusy() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isWorking: false,
            sessionState: "busy",
            hasNotification: false
        )
        XCTAssertEqual(state, .working)
    }

    func testWorkingWhenRunningAndSessionRetry() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isWorking: false,
            sessionState: "retry",
            hasNotification: false
        )
        XCTAssertEqual(state, .working)
    }

    func testIdleWhenRunningButQuiet() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isWorking: false,
            sessionState: nil,
            hasNotification: false
        )
        XCTAssertEqual(state, .idle)
    }

    func testIdleWhenExited() {
        let state = paneActivityState(
            processState: .exited(code: 0),
            isWorking: false,
            sessionState: nil,
            hasNotification: false
        )
        XCTAssertEqual(state, .idle)
    }

    func testIdleWhenExitedRegardlessOfStaleWorkingSignal() {
        let state = paneActivityState(
            processState: .exited(code: 0),
            isWorking: true,
            sessionState: "busy",
            hasNotification: false
        )
        XCTAssertEqual(state, .idle)
    }

    func testIdleWhenProcessNil() {
        let state = paneActivityState(
            processState: nil,
            isWorking: false,
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
            isWorking: false,
            sessionState: nil,
            hasNotification: true
        )
        let withoutNotification = paneActivityState(
            processState: .running(pid: 1),
            isWorking: false,
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
                processState: .running(pid: 1), isWorking: true, sessionState: "busy", hasNotification: false),
            paneActivityState(
                processState: .running(pid: 1), isWorking: false, sessionState: nil, hasNotification: false),
            paneActivityState(
                processState: .exited(code: 0), isWorking: false, sessionState: nil, hasNotification: false),
            paneActivityState(processState: nil, isWorking: false, sessionState: nil, hasNotification: false),
        ]
        for state in states {
            XCTAssertNotEqual(state, .waiting, "Expected non-waiting without notification, got \(state)")
        }
    }

    func testNotificationAlwaysWaiting() {
        let states: [PaneActivityState] = [
            paneActivityState(
                processState: .running(pid: 1), isWorking: true, sessionState: "busy", hasNotification: true),
            paneActivityState(
                processState: .running(pid: 1), isWorking: false, sessionState: nil, hasNotification: true),
            paneActivityState(
                processState: .exited(code: 0), isWorking: false, sessionState: nil, hasNotification: true),
            paneActivityState(processState: nil, isWorking: false, sessionState: nil, hasNotification: true),
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

    // MARK: - visual appearance separation

    func testWorkingAndWaitingUseDistinctCircularAppearances() {
        let working = activityIndicatorAppearance(for: .working)
        let waiting = activityIndicatorAppearance(for: .waiting)

        XCTAssertEqual(working.geometry, .circle)
        XCTAssertEqual(waiting.geometry, .circle)
        XCTAssertEqual(working.palette, .secondary)
        XCTAssertEqual(waiting.palette, .accent)
        XCTAssertLessThan(working.opacityRange.upperBound, waiting.opacityRange.upperBound)
        XCTAssertGreaterThan(working.blurRadius, 0)
        XCTAssertEqual(waiting.blurRadius, 0)
    }

    func testWaitingAppearanceIsSolidRegardlessOfPulse() {
        let waiting = activityIndicatorAppearance(for: .waiting)
        XCTAssertEqual(
            waiting.resolvedOpacity(pulsing: true, reduceMotion: false),
            waiting.resolvedOpacity(pulsing: false, reduceMotion: false)
        )
        XCTAssertEqual(waiting.resolvedOpacity(pulsing: true, reduceMotion: false), 1)
    }

    func testWaitingIndicatorColorReflectsPriority() {
        XCTAssertEqual(waitingIndicatorColor(isPriority: true), .orange)
        XCTAssertEqual(waitingIndicatorColor(isPriority: false), .accentColor)
    }

    func testReduceMotionKeepsWorkingAndWaitingStaticallyDistinct() {
        let working = activityIndicatorAppearance(for: .working)
        let waiting = activityIndicatorAppearance(for: .waiting)

        XCTAssertEqual(working.resolvedOpacity(pulsing: true, reduceMotion: true), 0.85)
        XCTAssertEqual(waiting.resolvedOpacity(pulsing: true, reduceMotion: true), 1)
        XCTAssertNotEqual(
            working.resolvedOpacity(pulsing: true, reduceMotion: true),
            waiting.resolvedOpacity(pulsing: true, reduceMotion: true)
        )
    }

    // MARK: - Claude lifecycle parsing and edge-once tracing

    func testClaudeLifecyclePayloadTransitionsWorkingAndIdle() {
        let monitor = StatusLineMonitor(paneID: UUID(), cliType: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        XCTAssertTrue(monitor.isClaudeWorking)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertFalse(monitor.isClaudeWorking)
    }

    func testClaudeStopFailureTransitionsIdle() {
        let monitor = StatusLineMonitor(paneID: UUID(), cliType: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"StopFailure"}"#.utf8))
        XCTAssertFalse(monitor.isClaudeWorking)
    }

    func testClaudeActivityChangedTraceOnlyFiresOnEdges() {
        let monitor = StatusLineMonitor(paneID: UUID(), cliType: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))

        let changed = TracingService.shared.recordedEventsForTesting.filter { $0.name == "pane.activity.changed" }
        XCTAssertEqual(changed.count, 2)
        XCTAssertEqual(changed.map { $0.attributes["state"] }, ["working", "idle"])
        XCTAssertEqual(changed.map { $0.attributes["source"] }, ["claude_hook", "claude_hook"])
        XCTAssertEqual(changed.map { $0.attributes["hook_event"] }, ["UserPromptSubmit", "Stop"])
    }

    func testClaudeActivityIgnoresMalformedAndUnrelatedPayloads() {
        let monitor = StatusLineMonitor(paneID: UUID(), cliType: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"PreToolUse"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data("not json".utf8))
        XCTAssertFalse(monitor.isClaudeWorking)
        XCTAssertTrue(TracingService.shared.recordedEventsForTesting.isEmpty)
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
