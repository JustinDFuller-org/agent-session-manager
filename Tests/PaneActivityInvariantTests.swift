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

    func testStoppedWhenRunningAndStopped() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isWorking: false,
            isStopped: true,
            sessionState: nil,
            hasNotification: false
        )
        XCTAssertEqual(state, .stopped)
    }

    func testWaitingBeatsStoppedWhenHasNotification() {
        let state = paneActivityState(
            processState: .running(pid: 1),
            isWorking: false,
            isStopped: true,
            sessionState: nil,
            hasNotification: true
        )
        XCTAssertEqual(state, .waiting)
    }

    func testStoppedIsIdleWhenProcessExited() {
        let state = paneActivityState(
            processState: .exited(code: 0),
            isWorking: false,
            isStopped: true,
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

    func testTabStoppedIfAnyPaneStopped() {
        XCTAssertEqual(tabActivityState([.idle, .stopped]), .stopped)
    }

    func testTabWorkingBeatsStoped() {
        XCTAssertEqual(tabActivityState([.working, .stopped]), .working)
    }

    func testTabWaitingBeatsStopped() {
        XCTAssertEqual(tabActivityState([.waiting, .stopped]), .waiting)
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
        XCTAssertEqual(waitingIndicatorColor(isPriority: false), Theme.accent)
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

    func testStoppedAppearanceUsesOctagonGeometry() {
        let stopped = activityIndicatorAppearance(for: .stopped)
        XCTAssertEqual(stopped.geometry, .octagon)
        XCTAssertEqual(stopped.palette, .secondary)
        XCTAssertEqual(stopped.blurRadius, 0)
        XCTAssertEqual(stopped.opacityRange, 0.5...0.5)
    }

    // MARK: - Claude lifecycle parsing and edge-once tracing

    func testClaudeLifecyclePayloadTransitionsWorkingAndIdle() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        XCTAssertTrue(monitor.isClaudeWorking)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertFalse(monitor.isClaudeWorking)
    }

    func testClaudeStopFailureTransitionsIdle() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"StopFailure"}"#.utf8))
        XCTAssertFalse(monitor.isClaudeWorking)
    }

    func testClaudeActivityChangedTraceOnlyFiresOnEdges() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))

        let changed = TracingService.shared.recordedEventsForTesting.filter { $0.name == "pane.activity.changed" }
        XCTAssertEqual(changed.count, 2)
        XCTAssertEqual(changed.map { $0.attributes["state"] }, ["working", "stopped"])
        XCTAssertEqual(changed.map { $0.attributes["source"] }, ["claude_hook", "claude_hook"])
        XCTAssertEqual(changed.map { $0.attributes["hook_event"] }, ["UserPromptSubmit", "Stop"])
    }

    func testClaudeLifecycleIsStoppedAfterStop() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertTrue(monitor.isClaudeStopped)
        XCTAssertFalse(monitor.isClaudeWorking)
    }

    func testCursorLifecycleTransitionsWorkingAndStopped() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .cursor)
        monitor.testApplyCursorActivity(isWorking: true)
        XCTAssertTrue(monitor.isCursorWorking)
        XCTAssertFalse(monitor.isCursorStopped)
        monitor.testApplyCursorActivity(isWorking: false)
        XCTAssertFalse(monitor.isCursorWorking)
        XCTAssertTrue(monitor.isCursorStopped)
    }

    func testClaudeStopWithNoPriorWorkingIsIgnored() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertFalse(monitor.isClaudeWorking)
        XCTAssertFalse(monitor.isClaudeStopped)
        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertTrue(events.allSatisfy { $0.name != "pane.activity.changed" })
        XCTAssertEqual(events.last?.attributes["decision"], "ignored_not_working")
    }

    func testOnClaudeStoppedCallbackFiresOncePerEdge() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.stopNotificationGracePeriod = 0
        var callCount = 0
        monitor.onClaudeStopped = { callCount += 1 }

        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertEqual(callCount, 1)

        // Duplicate Stop — already stopped, no second fire.
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertEqual(callCount, 1)
    }

    func testOnClaudeStoppedCallbackNotFiredForLoneStop() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.stopNotificationGracePeriod = 0
        var callCount = 0
        monitor.onClaudeStopped = { callCount += 1 }
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertEqual(callCount, 0)
    }

    // MARK: - Stop notification grace-delay

    func testGracePeriodZeroFiresImmediatelyOnStop() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.stopNotificationGracePeriod = 0
        var callCount = 0
        monitor.onClaudeStopped = { callCount += 1 }

        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertEqual(callCount, 1)
    }

    func testForcedContinueWithinGraceCancelsSpuriousChime() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.stopNotificationGracePeriod = 0.05
        var callCount = 0
        monitor.onClaudeStopped = { callCount += 1 }

        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertTrue(monitor.isClaudeStopped, "lifecycle flips to stopped immediately regardless of grace")

        // Forced continuation resumes before the grace period elapses — cancels the false first chime.
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        XCTAssertEqual(callCount, 0)

        let expectation = XCTestExpectation(description: "grace period elapses without firing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(callCount, 0)

        // The real stop still fires exactly once.
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        let realStopExpectation = XCTestExpectation(description: "real stop fires after grace period")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { realStopExpectation.fulfill() }
        wait(for: [realStopExpectation], timeout: 1)
        XCTAssertEqual(callCount, 1)
    }

    func testClaudeActivityIgnoresMalformedAndUnrelatedPayloads() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"SomeUnknownHook"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data("not json".utf8))
        XCTAssertFalse(monitor.isClaudeWorking)
        XCTAssertTrue(TracingService.shared.recordedEventsForTesting.isEmpty)
    }

    // MARK: - Background-agent gating (statusline.hook.event + outstanding count)

    func testPreToolUseAgentLaunchIncrementsOutstandingCount() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"PreToolUse","tool_name":"Task"}"#.utf8))
        let events = TracingService.shared.recordedEventsForTesting.filter { $0.name == "statusline.hook.event" }
        XCTAssertEqual(events.last?.attributes["outstanding_count"], "1")
    }

    func testSubagentStopDecrementsOutstandingCountFlooredAtZero() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"SubagentStop"}"#.utf8))
        let events = TracingService.shared.recordedEventsForTesting.filter { $0.name == "statusline.hook.event" }
        XCTAssertEqual(events.last?.attributes["outstanding_count"], "0")
    }

    func testStopIsSuppressedWhileBackgroundAgentsAreOutstanding() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        var callCount = 0
        monitor.onClaudeStopped = { callCount += 1 }

        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"PreToolUse","tool_name":"Task"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))

        XCTAssertEqual(callCount, 0)
        XCTAssertTrue(monitor.isClaudeWorking, "pane should still read working while a background agent is outstanding")
        let hookEvents = TracingService.shared.recordedEventsForTesting.filter { $0.name == "statusline.hook.event" }
        XCTAssertEqual(hookEvents.last?.attributes["decision"], "suppressed_background_agents")
    }

    func testPlanModeSequenceFiresStopOnceAfterAllBackgroundAgentsComplete() {
        let monitor = StatusLineMonitor(paneID: UUID(), harness: .claude)
        monitor.stopNotificationGracePeriod = 0
        var callCount = 0
        monitor.onClaudeStopped = { callCount += 1 }

        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"UserPromptSubmit"}"#.utf8))
        // Plan mode launches two background Explore agents.
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"PreToolUse","tool_name":"Task"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"PreToolUse","tool_name":"Task"}"#.utf8))

        // Main agent finishes its turn while both children are still running — must be suppressed.
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertEqual(callCount, 0)
        XCTAssertTrue(monitor.isClaudeWorking)

        // First background agent completes; re-wake produces another Stop — still one outstanding.
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"SubagentStop"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertEqual(callCount, 0)
        XCTAssertTrue(monitor.isClaudeWorking)

        // Second background agent completes; the final Stop is the genuine "done" edge.
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"SubagentStop"}"#.utf8))
        monitor.testApplyClaudeActivityPayload(Data(#"{"hook_event_name":"Stop"}"#.utf8))
        XCTAssertEqual(callCount, 1)
        XCTAssertTrue(monitor.isClaudeStopped)

        let hookEvents = TracingService.shared.recordedEventsForTesting.filter { $0.name == "statusline.hook.event" }
        let stopDecisions = hookEvents.filter { $0.attributes["hook_event"] == "Stop" }.map {
            $0.attributes["decision"]
        }
        XCTAssertEqual(
            stopDecisions,
            ["suppressed_background_agents", "suppressed_background_agents", "fired"]
        )
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
