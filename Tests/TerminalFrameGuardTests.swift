import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalFrameGuardTests: XCTestCase {
    func testTinyFrameIsRejectedWhenTerminalHasReasonableColumns() {
        let controller = TerminalController()
        let view = controller.terminalView

        view.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        view.layoutSubtreeIfNeeded()
        #endif

        let colsAfterSetup = view.getTerminal().cols
        XCTAssertGreaterThan(colsAfterSetup, 2, "terminal should have multiple columns after layout")

        view.setFrameSize(NSSize(width: 1, height: 480))

        let colsAfterTinyFrame = view.getTerminal().cols
        XCTAssertEqual(
            colsAfterTinyFrame, colsAfterSetup,
            "a 1px-wide transient frame must not resize the terminal"
        )
    }

    func testZeroWidthFrameIsRejected() {
        let controller = TerminalController()
        let view = controller.terminalView

        view.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        view.layoutSubtreeIfNeeded()
        #endif

        let colsBefore = view.getTerminal().cols
        XCTAssertGreaterThan(colsBefore, 2)

        view.setFrameSize(NSSize(width: 0, height: 480))

        XCTAssertEqual(
            view.getTerminal().cols, colsBefore,
            "a zero-width frame must not resize the terminal"
        )
    }

    func testLegitimateResizeIsAllowed() {
        let controller = TerminalController()
        let view = controller.terminalView

        view.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        view.layoutSubtreeIfNeeded()
        #endif

        let colsBefore = view.getTerminal().cols
        XCTAssertGreaterThan(colsBefore, 2)

        view.setFrameSize(NSSize(width: 320, height: 480))

        let colsAfter = view.getTerminal().cols
        XCTAssertLessThan(
            colsAfter, colsBefore,
            "a legitimate smaller frame should reduce column count"
        )
        XCTAssertGreaterThan(colsAfter, 2, "legitimate resize still has multiple columns")
    }

    func testFirstFrameIsNotBlocked() {
        let controller = TerminalController()
        let view = controller.terminalView

        XCTAssertEqual(view.frame.width, 0, "starts with zero frame")

        view.setFrameSize(NSSize(width: 640, height: 480))

        let cols = view.getTerminal().cols
        XCTAssertGreaterThan(cols, 2, "initial frame must be accepted")
    }
}
