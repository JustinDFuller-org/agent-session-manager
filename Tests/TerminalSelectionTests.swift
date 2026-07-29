import AppKit
import XCTest

@testable import AgentSessionManager

@MainActor
final class TerminalSelectionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TracingService.shared.enableTestCapture()
        InvariantReporter.shared.enableTestCapture()
    }

    override func tearDown() {
        TracingService.shared.resetForTesting()
        InvariantReporter.shared.resetForTesting()
        super.tearDown()
    }

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

    func testCopyWithSelectionPutsTextOnPasteboardAndClearsSelection() async {
        let pasteboard = NSPasteboard.general
        let priorContents = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let priorContents { pasteboard.setString(priorContents, forType: .string) }
        }

        let controller = TerminalController()
        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif
        controller.terminalView.feed(text: "hello world\n")
        try? await Task.sleep(nanoseconds: 100_000_000)
        controller.terminalView.selectAll()

        let copied = controller.terminalView.copySelectionToPasteboard()

        XCTAssertTrue(copied)
        XCTAssertFalse(controller.terminalView.selectionActive)
        XCTAssertEqual(pasteboard.string(forType: .string)?.contains("hello world"), true)
        XCTAssertTrue(
            TracingService.shared.recordedEventsForTesting.contains { $0.name == "terminal.clipboard.copied" }
        )
        let copyEvent = TracingService.shared.recordedEventsForTesting.first { $0.name == "terminal.clipboard.copied" }
        XCTAssertNotNil(copyEvent?.attributes["chars"])
        XCTAssertFalse(copyEvent?.attributes.values.contains(where: { $0.contains("hello world") }) ?? true)
    }

    func testCopyWithoutSelectionLeavesPasteboardUntouchedAndReportsInvariant() {
        let pasteboard = NSPasteboard.general
        let priorContents = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let priorContents { pasteboard.setString(priorContents, forType: .string) }
        }
        pasteboard.clearContents()
        pasteboard.setString("preexisting", forType: .string)

        let controller = TerminalController()
        XCTAssertFalse(controller.terminalView.selectionActive)

        let copied = controller.terminalView.copySelectionToPasteboard()

        XCTAssertFalse(copied)
        XCTAssertEqual(pasteboard.string(forType: .string), "preexisting")
        XCTAssertTrue(
            InvariantReporter.shared.violationsForTesting.contains {
                $0.invariantID == "terminal.clipboard.copy_requires_selection"
            }
        )
    }

    func testHasSelectionTracksSelectAllAndSelectNone() {
        let controller = TerminalController()
        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif

        XCTAssertFalse(controller.hasSelection)

        controller.terminalView.selectAll()
        XCTAssertTrue(controller.hasSelection)

        controller.terminalView.selectNone()
        XCTAssertFalse(controller.hasSelection)
    }

    func testPasteFromEmptyPasteboardDoesNothing() {
        let pasteboard = NSPasteboard.general
        let priorContents = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let priorContents { pasteboard.setString(priorContents, forType: .string) }
        }
        pasteboard.clearContents()

        let controller = TerminalController()
        var receivedUserInput = false
        controller.terminalView.onUserInput = { receivedUserInput = true }

        let pasted = controller.terminalView.pasteFromPasteboard()

        XCTAssertFalse(pasted)
        XCTAssertFalse(receivedUserInput)
    }

    func testPasteFromSeededPasteboardFiresUserInput() {
        let pasteboard = NSPasteboard.general
        let priorContents = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let priorContents { pasteboard.setString(priorContents, forType: .string) }
        }
        pasteboard.clearContents()
        pasteboard.setString("pasted text", forType: .string)

        let controller = TerminalController()
        controller.terminalView.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        #if os(macOS)
        controller.terminalView.layoutSubtreeIfNeeded()
        #endif
        var receivedUserInput = false
        controller.terminalView.onUserInput = { receivedUserInput = true }

        let pasted = controller.terminalView.pasteFromPasteboard()

        XCTAssertTrue(pasted)
        XCTAssertTrue(receivedUserInput)
        XCTAssertTrue(
            TracingService.shared.recordedEventsForTesting.contains { $0.name == "terminal.clipboard.pasted" }
        )
    }
}
