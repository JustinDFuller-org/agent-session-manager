import AppKit
import XCTest

@testable import AgentSessionManager

@MainActor
final class WindowEventRoutingTests: XCTestCase {
    func testRoutesEventsFromHostWindow() {
        let hostWindow = NSWindow()
        let eventWindow = hostWindow

        XCTAssertTrue(WindowEventRouting.shouldHandleMainWindowEvent(hostWindow: hostWindow, eventWindow: eventWindow))
    }

    func testIgnoresEventsFromAuxiliaryWindow() {
        let hostWindow = NSWindow()
        let auxiliaryWindow = NSWindow()

        XCTAssertFalse(
            WindowEventRouting.shouldHandleMainWindowEvent(hostWindow: hostWindow, eventWindow: auxiliaryWindow))
    }

    func testIgnoresNilOrMissingWindows() {
        let hostWindow = NSWindow()

        XCTAssertFalse(WindowEventRouting.shouldHandleMainWindowEvent(hostWindow: hostWindow, eventWindow: nil))
        XCTAssertFalse(WindowEventRouting.shouldHandleMainWindowEvent(hostWindow: nil, eventWindow: hostWindow))
        XCTAssertFalse(WindowEventRouting.shouldHandleMainWindowEvent(hostWindow: nil, eventWindow: nil))
    }
}
