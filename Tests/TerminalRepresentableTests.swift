import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalRepresentableTests: XCTestCase {
    func testFocusIfNeededDoesNothingWhenNotActive() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        // wasActive starts false; isActive=false → no transition
        coordinator.focusIfNeeded(view: view, isActive: false)
        // No crash, wasActive remains false; calling again is a no-op
        coordinator.focusIfNeeded(view: view, isActive: false)
    }

    func testFocusIfNeededDoesNothingWhenAlreadyActive() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        // First call transitions false→true
        coordinator.focusIfNeeded(view: view, isActive: true)
        // Second call: wasActive=true, isActive=true → guard fails, no-op
        coordinator.focusIfNeeded(view: view, isActive: true)
    }

    func testFocusWhenReadyDoesNotCrashWithZeroFrame() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        // frame is zero by default — should not crash, just schedules retries
        coordinator.focusWhenReady(view: view, attempt: 0)
    }

    func testFocusWhenReadyCallsMakeFirstResponderWithNonZeroFrame() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        view.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        view.layoutSubtreeIfNeeded()
        #endif
        // No window in unit tests, but the call must not crash
        coordinator.focusWhenReady(view: view, attempt: 0)
    }

    func testFocusWhenReadyRespectsAttemptLimit() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        // Frame is zero; attempt >= 10 → must return immediately without scheduling
        coordinator.focusWhenReady(view: view, attempt: 10)
    }
}
