import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalContentTests: XCTestCase {
    func testRenderedScreenTextReplacesNullCellsWithSpaces() {
        // An unstarted terminal with a non-zero frame has null-filled cells.
        // Null cells must become spaces, which trailing-space trimming collapses
        // to empty — the output is "" not a string of ^@ characters.
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
        // Feed ANSI sequences that place "Hello" at col 1 and "World" at col 10,
        // leaving null cells in the gap. The rendered text must use spaces for
        // those null cells so that the layout is preserved (matching what the
        // visual renderer does in buildAttributedString).
        let controller = TerminalController()
        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif
        // ESC[1;1H  — move cursor to row 1, col 1 (1-based)
        // Hello     — 5 chars, cols 1-5
        // ESC[1;11H — move cursor to row 1, col 11 (0-indexed gap at cols 6-10)
        // World     — 5 chars, cols 11-15
        let ansi = "\u{1B}[1;1HHello\u{1B}[1;11HWorld"
        let bytes = Array(ansi.utf8)
        controller.terminalView.feed(byteArray: ArraySlice(bytes))
        let content = controller.terminalContent
        for scalar in content.unicodeScalars {
            XCTAssertNotEqual(scalar.value, 0, "must not contain null characters (U+0000)")
        }
        XCTAssertTrue(content.contains("Hello"), "must contain Hello")
        XCTAssertTrue(content.contains("World"), "must contain World")
        // Null cells between the two words must be rendered as spaces, not collapsed.
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
