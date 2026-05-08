import XCTest
@testable import AgentSessionManager

@MainActor
final class DebugLoggerTests: XCTestCase {

    private var testTraceDir: URL!

    override func setUp() {
        super.setUp()
        testTraceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("asm-debug-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: testTraceDir, withIntermediateDirectories: true)
        let file = testTraceDir.appendingPathComponent("trace.log")
        DebugLogger.shared.adoptTraceFileForTesting(url: file, maxBytes: 80_000)
        DebugLogger.shared.isEnabled = false
        DebugLogger.shared.removeAllTracedPanes()
        DebugLogger.shared.clear()
    }

    override func tearDown() {
        DebugLogger.shared.isEnabled = false
        DebugLogger.shared.removeAllTracedPanes()
        DebugLogger.shared.clear()
        if let testTraceDir {
            try? FileManager.default.removeItem(at: testTraceDir)
        }
        super.tearDown()
    }

    private func traceContents() throws -> String {
        DebugLogger.shared.flushFileWritesForTesting()
        return try String(contentsOf: DebugLogger.shared.traceFileURL, encoding: .utf8)
    }

    func testNoFileContentWhenDisabled() throws {
        DebugLogger.shared.log("nope")
        DebugLogger.shared.flushFileWritesForTesting()
        XCTAssertFalse(FileManager.default.fileExists(atPath: DebugLogger.shared.traceFileURL.path))
    }

    func testGlobalLineWritesFile() throws {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log("hello world")
        let s = try traceContents()
        XCTAssertTrue(s.contains("[global]"))
        XCTAssertTrue(s.contains("hello world"))
    }

    func testPaneAttributionInFile() throws {
        let id = UUID()
        DebugLogger.shared.setPaneTraceEnabled(id, true)
        DebugLogger.shared.log("pane-event", paneID: id, tabName: "My Tab", paneName: "my-pane")
        let s = try traceContents()
        XCTAssertTrue(s.contains("[tab: My Tab] [pane: my-pane]"))
        XCTAssertTrue(s.contains("pane-event"))
    }

    func testClearTruncatesFile() throws {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log("before")
        _ = try traceContents()
        DebugLogger.shared.clear()
        DebugLogger.shared.flushFileWritesForTesting()
        XCTAssertFalse(FileManager.default.fileExists(atPath: DebugLogger.shared.traceFileURL.path))
    }

    func testTrimRemovesOldestBytesWhenOverMax() throws {
        DebugLogger.shared.adoptTraceFileForTesting(url: testTraceDir.appendingPathComponent("small.log"), maxBytes: 3000)
        DebugLogger.shared.isEnabled = true
        let filler = String(repeating: "x", count: 400)
        for i in 0..<20 {
            DebugLogger.shared.log("line-\(i)-\(filler)")
        }
        let s = try traceContents()
        XCTAssertTrue(s.contains("--- [truncated older log entries] ---"))
        XCTAssertFalse(s.contains("line-0-"))
    }

    func testRedactSensitiveEnvStyleLineRedactsTokenLikeKeys() {
        XCTAssertEqual(
            DebugLogger.redactSensitiveEnvStyleLine("  JIRA_TOKEN=at-secret"),
            "JIRA_TOKEN=<redacted>"
        )
        XCTAssertEqual(
            DebugLogger.redactSensitiveEnvStyleLine("PATH=/usr/bin"),
            "PATH=/usr/bin"
        )
    }

    func testRedactSensitiveEnvStyleLinesMultiline() {
        let raw = "line a\n  DATADOG_API_KEY=abc123\nHOME=/Users/me"
        let out = DebugLogger.redactSensitiveEnvStyleLines(raw)
        XCTAssertTrue(out.contains("DATADOG_API_KEY=<redacted>"))
        XCTAssertTrue(out.contains("HOME=/Users/me"))
    }

    func testBuildBugReportTextMentionsTracePath() {
        let path = "/tmp/example-trace.log"
        let body = DebugLogger.shared.buildBugReportText(traceFilePath: path)
        XCTAssertTrue(body.contains(path))
        XCTAssertTrue(body.contains("### System"))
    }

    func testLogTerminalContentRespectsGlobalGate() throws {
        let id = UUID()
        var app = AppSettings()
        app.debugLoggingEnabled = true
        app.debugLogIncludeTerminalContents = false
        DebugLogger.shared.syncFromAppSettings(app)
        DebugLogger.shared.isEnabled = true

        DebugLogger.shared.logTerminalContent(paneName: "p", content: "secret", tabName: "T", paneID: id)
        DebugLogger.shared.flushFileWritesForTesting()
        XCTAssertFalse(FileManager.default.fileExists(atPath: DebugLogger.shared.traceFileURL.path))

        app.debugLogIncludeTerminalContents = true
        DebugLogger.shared.syncFromAppSettings(app)
        DebugLogger.shared.logTerminalContent(paneName: "p", content: "visible", tabName: "T", paneID: id)
        let s = try traceContents()
        XCTAssertTrue(s.contains("Terminal Content"))
        XCTAssertTrue(s.contains("visible"))
    }

    func testLogTerminalContentPerPaneWithoutGlobal() throws {
        let id = UUID()
        var app = AppSettings()
        app.debugLoggingEnabled = false
        app.debugLogIncludeTerminalContents = false
        DebugLogger.shared.syncFromAppSettings(app)
        DebugLogger.shared.setPaneTerminalCaptureEnabled(id, true)

        DebugLogger.shared.logTerminalContent(paneName: "p", content: "from-pane", tabName: "T", paneID: id)
        let s = try traceContents()
        XCTAssertTrue(s.contains("from-pane"))
    }

    func testLogWithPaneIDWithoutTracingIsIgnored() throws {
        let id = UUID()
        DebugLogger.shared.isEnabled = false
        DebugLogger.shared.log("skip", paneID: id, tabName: "T", paneName: "P")
        DebugLogger.shared.flushFileWritesForTesting()
        XCTAssertFalse(FileManager.default.fileExists(atPath: DebugLogger.shared.traceFileURL.path))
    }

    func testLogGitCommandWhenEnabled() throws {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.logGitCommand(["status"], cwd: "/tmp")
        let s = try traceContents()
        XCTAssertTrue(s.contains("Git Command"))
        XCTAssertTrue(s.contains("git status"))
    }

    func testLogWorktreeResolutionWhenEnabled() throws {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.logWorktreeResolution(userRef: "feat/x", result: "ok")
        let s = try traceContents()
        XCTAssertTrue(s.contains("feat/x"))
        XCTAssertTrue(s.contains("ok"))
    }
}
