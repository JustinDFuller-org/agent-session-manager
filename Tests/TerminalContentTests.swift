import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalContentTests: XCTestCase {
    func testTerminalContentFiltersNullCharacters() {
        let controller = TerminalController()
        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)

        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif

        controller.startProcess()
        let content = controller.terminalContent
        for scalar in content.unicodeScalars {
            XCTAssertNotEqual(scalar.value, 0, "terminalContent must not contain null characters (U+0000)")
        }
    }

    func testTerminalContentReturnsEmptyForUnstartedTerminal() {
        let controller = TerminalController()
        let content = controller.terminalContent
        XCTAssertEqual(content, "")
    }
}
