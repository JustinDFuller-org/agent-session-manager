import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalBellNotificationTests: XCTestCase {
    func testWireTerminalBellForNotificationsAddsWhenPaneIsNotActive() async {
        let appState = AppState()
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp", directoryHint: .isDirectory))
        let pane = tab.addPane(name: "p1")
        appState.activePaneID = UUID()
        XCTAssertNotNil(pane.terminalController, "Unit tests run without --uitesting; terminal should exist")

        pane.wireTerminalBellForNotifications(appState: appState, tab: tab, isPriority: true)
        pane.terminalController?.onBell?()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(appState.notifications.count, 1)
        XCTAssertEqual(appState.notifications.first?.paneID, pane.id)
        XCTAssertEqual(appState.notifications.first?.tabID, tab.id)
        XCTAssertTrue(appState.notifications.first?.isPriority ?? false)
    }

    func testWireTerminalBellForNotificationsAddsWhenPaneIsActive() async {
        let appState = AppState()
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp", directoryHint: .isDirectory))
        let pane = tab.addPane(name: "p1")
        appState.activePaneID = pane.id

        pane.wireTerminalBellForNotifications(appState: appState, tab: tab, isPriority: false)
        pane.terminalController?.onBell?()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(appState.notifications.count, 1)
        XCTAssertEqual(appState.notifications.first?.paneID, pane.id)
    }

    func testBellFeedInvokesOnBell() async {
        let controller = TerminalController()
        let fired = LockedFlag()
        controller.onBell = { fired.set(true) }

        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif

        controller.terminalView.feed(byteArray: [0x07])
        try? await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertTrue(fired.value, "BEL (0x07) should reach bell() and invoke onBell")
    }

    func testTogglingPriorityAtRuntimeAffectsSubsequentNotifications() async {
        let appState = AppState()
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp", directoryHint: .isDirectory))
        let pane = tab.addPane(name: "p1")
        appState.activePaneID = UUID()

        pane.wireTerminalBellForNotifications(appState: appState, tab: tab, isPriority: false)
        pane.terminalController?.onBell?()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(appState.notifications.count, 1)
        XCTAssertFalse(appState.notifications[0].isPriority, "Initial notification should not be priority")

        appState.clearNotification(paneID: pane.id)
        pane.isPriority = true
        pane.terminalController?.onBell?()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(appState.notifications.count, 1)
        XCTAssertTrue(appState.notifications[0].isPriority, "After toggling isPriority, notification should be priority")
    }

    func testOsc777NotifyInvokesOnBell() async {
        let controller = TerminalController()
        let fired = LockedFlag()
        controller.onBell = { fired.set(true) }

        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif

        // SwiftTerm: ESC ] 777 ; notify ; title ; body BEL
        controller.terminalView.feed(text: "\u{1b}]777;notify;OSC Title;OSC Body\u{07}")
        try? await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertTrue(fired.value, "OSC 777 notify should invoke the same attention path as BEL")
    }
}

/// Thread-safe flag for closure capture in async bell test.
private final class LockedFlag: @unchecked Sendable {
    private var _value = false
    private let lock = NSLock()

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set(_ newValue: Bool) {
        lock.lock()
        _value = newValue
        lock.unlock()
    }
}
