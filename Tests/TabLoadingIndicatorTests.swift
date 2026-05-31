import XCTest

@testable import AgentSessionManager

@MainActor
final class TabLoadingIndicatorTests: XCTestCase {
    private func makeTab() -> Tab {
        Tab(name: "test", directory: URL(filePath: "/tmp"))
    }

    func testNoPanes() {
        let tab = makeTab()
        XCTAssertFalse(tab.hasRunningPane)
    }

    func testPaneWithNilController() {
        let tab = makeTab()
        let pane = Pane(name: "p", tab: tab)
        pane.installTerminalController(nil)
        tab.panes = [pane]
        XCTAssertFalse(tab.hasRunningPane)
    }

    func testPaneWithIdleController() {
        let tab = makeTab()
        let pane = Pane(name: "p", tab: tab)
        let controller = TerminalController()
        controller.processState = .idle
        pane.installTerminalController(controller)
        tab.panes = [pane]
        XCTAssertFalse(tab.hasRunningPane)
    }

    func testPaneWithRunningController() {
        let tab = makeTab()
        let pane = Pane(name: "p", tab: tab)
        let controller = TerminalController()
        controller.processState = .running(pid: 1234)
        pane.installTerminalController(controller)
        tab.panes = [pane]
        XCTAssertTrue(tab.hasRunningPane)
    }

    func testPaneWithExitedZeroController() {
        let tab = makeTab()
        let pane = Pane(name: "p", tab: tab)
        let controller = TerminalController()
        controller.processState = .exited(code: 0)
        pane.installTerminalController(controller)
        tab.panes = [pane]
        XCTAssertFalse(tab.hasRunningPane)
    }

    func testPaneWithExitedNilController() {
        let tab = makeTab()
        let pane = Pane(name: "p", tab: tab)
        let controller = TerminalController()
        controller.processState = .exited(code: nil)
        pane.installTerminalController(controller)
        tab.panes = [pane]
        XCTAssertFalse(tab.hasRunningPane)
    }

    func testMixedPanesReturnsTrueWhenAnyRunning() {
        let tab = makeTab()
        let runningPane = Pane(name: "running", tab: tab)
        let runningController = TerminalController()
        runningController.processState = .running(pid: 42)
        runningPane.installTerminalController(runningController)

        let exitedPane = Pane(name: "exited", tab: tab)
        let exitedController = TerminalController()
        exitedController.processState = .exited(code: 0)
        exitedPane.installTerminalController(exitedController)

        let idlePane = Pane(name: "idle", tab: tab)
        let idleController = TerminalController()
        idleController.processState = .idle
        idlePane.installTerminalController(idleController)

        tab.panes = [runningPane, exitedPane, idlePane]
        XCTAssertTrue(tab.hasRunningPane)
    }

    func testAllExitedReturnsFalse() {
        let tab = makeTab()
        let pane1 = Pane(name: "p1", tab: tab)
        let c1 = TerminalController()
        c1.processState = .exited(code: 0)
        pane1.installTerminalController(c1)

        let pane2 = Pane(name: "p2", tab: tab)
        let c2 = TerminalController()
        c2.processState = .exited(code: 1)
        pane2.installTerminalController(c2)

        tab.panes = [pane1, pane2]
        XCTAssertFalse(tab.hasRunningPane)
    }

    func testTransitionFromRunningToExited() {
        let tab = makeTab()
        let pane = Pane(name: "p", tab: tab)
        let controller = TerminalController()
        controller.processState = .running(pid: 99)
        pane.installTerminalController(controller)
        tab.panes = [pane]
        XCTAssertTrue(tab.hasRunningPane)

        controller.processState = .exited(code: 0)
        XCTAssertFalse(tab.hasRunningPane)
    }
}
