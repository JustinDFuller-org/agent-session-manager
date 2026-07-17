import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalSelectionTests: XCTestCase {
    func testMouseReportingDisabledSoSelectionSurvivesOutput() {
        let controller = TerminalController()

        XCTAssertFalse(controller.terminalView.allowMouseReporting)
    }

    func testSelectionSurvivesStreamingOutput() async {
        let controller = TerminalController()
        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif

        controller.terminalView.feed(text: "hello world\n")
        try? await Task.sleep(nanoseconds: 100_000_000)

        controller.terminalView.selectAll()
        XCTAssertTrue(controller.terminalView.selectionActive)

        controller.terminalView.feed(text: "more streaming output\n")
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(
            controller.terminalView.selectionActive,
            "Selection should survive PTY output while mouse reporting is disabled"
        )
        XCTAssertNotNil(controller.terminalView.getSelection())
    }
}
