import AppKit
import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalRepresentableTests: XCTestCase {
    func testFocusIfNeededDoesNothingWhenNotActive() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        coordinator.focusIfNeeded(view: view, isActive: false)
        coordinator.focusIfNeeded(view: view, isActive: false)
    }

    func testFocusIfNeededDoesNothingWhenAlreadyActive() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        coordinator.focusIfNeeded(view: view, isActive: true)
        coordinator.focusIfNeeded(view: view, isActive: true)
    }

    func testFocusWhenReadyDoesNotCrashWithZeroFrame() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        coordinator.focusWhenReady(view: view, attempt: 0)
    }

    func testFocusWhenReadyDoesNothingWithoutWindow() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        view.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        view.layoutSubtreeIfNeeded()
        #endif
        // Non-zero frame but no window: readiness guard must fail, no crash, schedules retry
        coordinator.focusWhenReady(view: view, attempt: 0)
        XCTAssertNil(view.window, "view must not be in a window for this test to be valid")
    }

    func testFocusBecomesFirstResponderOnceInWindow() {
        let controller = TerminalController()
        let view = controller.terminalView
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        view.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        window.contentView?.addSubview(view)
        view.layoutSubtreeIfNeeded()

        let coordinator = TerminalRepresentable.Coordinator()
        coordinator.focusWhenReady(view: view, attempt: 0)

        XCTAssertTrue(window.firstResponder === view, "terminal view must be first responder after focusWhenReady when in window")
    }

    func testFocusWhenReadyRespectsAttemptLimit() {
        let coordinator = TerminalRepresentable.Coordinator()
        let view = TerminalController().terminalView
        // attempt >= 10 → must return immediately without scheduling
        coordinator.focusWhenReady(view: view, attempt: 10)
    }
}
