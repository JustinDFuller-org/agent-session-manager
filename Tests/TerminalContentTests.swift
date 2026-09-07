import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalContentTests: XCTestCase {
    func testRenderedScreenTextReplacesNullCellsWithSpaces() {
        let controller = TerminalController()
        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif
        let content = controller.terminalContent
        XCTAssertEqual(content, "")
        for scalar in content.unicodeScalars {
            XCTAssertNotEqual(scalar.value, 0, "must not contain null characters (U+0000)")
        }
    }

    func testRenderedScreenTextPreservesLayoutBetweenWords() {
        let controller = TerminalController()
        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif
        let ansi = "\u{1B}[1;1HHello\u{1B}[1;11HWorld"
        let bytes = Array(ansi.utf8)
        controller.terminalView.feed(byteArray: ArraySlice(bytes))
        let content = controller.terminalContent
        for scalar in content.unicodeScalars {
            XCTAssertNotEqual(scalar.value, 0, "must not contain null characters (U+0000)")
        }
        XCTAssertTrue(content.contains("Hello"), "must contain Hello")
        XCTAssertTrue(content.contains("World"), "must contain World")
        XCTAssertTrue(
            content.contains("Hello     World"),
            "null cells between words must become spaces, preserving layout; got: \(content.debugDescription)"
        )
    }

    func testTerminalContentReturnsEmptyForUnstartedTerminal() {
        let controller = TerminalController()
        let content = controller.terminalContent
        XCTAssertEqual(content, "")
    }
}
