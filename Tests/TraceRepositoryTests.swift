import XCTest

@testable import AgentSessionManager

@MainActor
final class TraceRepositoryTests: XCTestCase {
    private var testDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("repo-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let testDir { try? FileManager.default.removeItem(at: testDir) }
        try await super.tearDown()
    }

    // MARK: Directory scan

    func testRefreshBuildsTabPaneTree() throws {
        try createPane(
            tabDir: "mytab-abcd1234", fileName: "mypane-efgh5678.jsonl",
            paneId: "efgh5678", paneName: "mypane", tabId: "abcd1234", tabName: "mytab")

        let repo = TraceRepository(tracesDirectory: testDir)
        repo.refresh()

        let nonGlobal = repo.tabs.filter { $0.id != "_global" }
        XCTAssertEqual(nonGlobal.count, 1)
        XCTAssertEqual(nonGlobal[0].name, "mytab")
        XCTAssertEqual(nonGlobal[0].panes.count, 1)
        XCTAssertEqual(nonGlobal[0].panes[0].name, "mypane")
    }

    func testRefreshIncludesGlobalTab() throws {
        let globalDir = testDir.appendingPathComponent("_global")
        try FileManager.default.createDirectory(at: globalDir, withIntermediateDirectories: true)
        let globalMeta = """
            {"_type":"metadata","paneId":"_global","paneName":"global","tabId":"_global","tabName":"_global","createdAt":"2026-01-01T00:00:00Z"}
            """
        try (globalMeta + "\n").write(
            to: globalDir.appendingPathComponent("global.jsonl"), atomically: true, encoding: .utf8)

        let repo = TraceRepository(tracesDirectory: testDir)
        repo.refresh()

        let global = repo.tabs.first { $0.id == "_global" }
        XCTAssertNotNil(global)
        XCTAssertEqual(global?.panes.count, 1)
    }

    func testRefreshEmptyDirectoryProducesNoTabs() {
        let repo = TraceRepository(tracesDirectory: testDir)
        repo.refresh()
        XCTAssertTrue(repo.tabs.isEmpty)
    }

    func testRefreshMultipleTabsAndPanes() throws {
        try createPane(
            tabDir: "tab1-aaaa1111", fileName: "pane1-bbbb2222.jsonl",
            paneId: "bbbb2222", paneName: "pane1", tabId: "aaaa1111", tabName: "tab1")
        try createPane(
            tabDir: "tab1-aaaa1111", fileName: "pane2-cccc3333.jsonl",
            paneId: "cccc3333", paneName: "pane2", tabId: "aaaa1111", tabName: "tab1")
        try createPane(
            tabDir: "tab2-dddd4444", fileName: "pane3-eeee5555.jsonl",
            paneId: "eeee5555", paneName: "pane3", tabId: "dddd4444", tabName: "tab2")

        let repo = TraceRepository(tracesDirectory: testDir)
        repo.refresh()

        let nonGlobal = repo.tabs.filter { $0.id != "_global" }
        XCTAssertEqual(nonGlobal.count, 2)
        let tab1 = nonGlobal.first { $0.name == "tab1" }
        XCTAssertEqual(tab1?.panes.count, 2)
    }

    // MARK: JSONL parsing

    func testParseSpansSkipsMetadataLine() {
        let content = """
            {"_type":"metadata","paneId":"p1","paneName":"pane1","tabId":"t1","tabName":"tab1","createdAt":"2026-01-01T00:00:00Z"}
            {"name":"real.event","traceId":"tid","spanId":"sid","startEpochMs":1000,"endEpochMs":1100,"durationMs":100,"attributes":{}}
            """
        let spans = TraceRepository.parseSpans(from: content)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].name, "real.event")
    }

    func testParseSpansHandlesMultipleSpans() {
        let content = """
            {"name":"e1","traceId":"t1","spanId":"s1","startEpochMs":1000,"endEpochMs":1100,"durationMs":100,"attributes":{}}
            {"name":"e2","traceId":"t2","spanId":"s2","startEpochMs":2000,"endEpochMs":2200,"durationMs":200,"attributes":{"k":"v"}}
            """
        let spans = TraceRepository.parseSpans(from: content)
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].name, "e1")
        XCTAssertEqual(spans[1].attributes["k"], "v")
    }

    func testParseSpansSkipsTruncationMarker() {
        let content = """
            --- [truncated older trace entries] ---
            {"name":"after.truncation","traceId":"t","spanId":"s","startEpochMs":1,"endEpochMs":2,"durationMs":1,"attributes":{}}
            """
        let spans = TraceRepository.parseSpans(from: content)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].name, "after.truncation")
    }

    func testParseSpansPreservesParentSpanId() {
        let content = """
            {"name":"child","traceId":"t","spanId":"s2","parentSpanId":"s1","startEpochMs":10,"endEpochMs":20,"durationMs":10,"attributes":{}}
            """
        let spans = TraceRepository.parseSpans(from: content)
        XCTAssertEqual(spans[0].parentSpanId, "s1")
    }

    func testSelectPaneLoadsSpansFromFile() throws {
        let tabDir = testDir.appendingPathComponent("tab1-aaaa", isDirectory: true)
        try FileManager.default.createDirectory(at: tabDir, withIntermediateDirectories: true)
        let paneFile = tabDir.appendingPathComponent("pane1-bbbb.jsonl")
        let content = """
            {"_type":"metadata","paneId":"bbbb","paneName":"pane1","tabId":"aaaa","tabName":"tab1","createdAt":"2026-01-01T00:00:00Z"}
            {"name":"loaded.event","traceId":"t","spanId":"s","startEpochMs":100,"endEpochMs":200,"durationMs":100,"attributes":{}}
            """
        try content.write(to: paneFile, atomically: true, encoding: .utf8)

        let repo = TraceRepository(tracesDirectory: testDir)
        repo.selectPane(paneFile)

        XCTAssertEqual(repo.selectedPaneSpans.count, 1)
        XCTAssertEqual(repo.selectedPaneSpans[0].name, "loaded.event")
    }

    func testSelectedPaneFollowsAtomicReplacementAndLaterWrites() async throws {
        let paneFile = testDir.appendingPathComponent("live.jsonl")
        try
            #"{"name":"initial","traceId":"t","spanId":"s1","startEpochMs":1,"endEpochMs":2,"durationMs":1,"attributes":{}}"#
            .write(to: paneFile, atomically: true, encoding: .utf8)
        let repo = TraceRepository(tracesDirectory: testDir)
        repo.selectPane(paneFile)

        try
            #"{"name":"replacement","traceId":"t","spanId":"s2","startEpochMs":2,"endEpochMs":3,"durationMs":1,"attributes":{}}"#
            .write(to: paneFile, atomically: true, encoding: .utf8)
        let replacementDeadline = Date().addingTimeInterval(2)
        while repo.selectedPaneSpans.first?.name != "replacement", Date() < replacementDeadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(repo.selectedPaneSpans.first?.name, "replacement")

        let handle = try FileHandle(forWritingTo: paneFile)
        try handle.seekToEnd()
        try handle.write(
            contentsOf: Data(
                ("\n"
                    + #"{"name":"appended","traceId":"t","spanId":"s3","startEpochMs":3,"endEpochMs":4,"durationMs":1,"attributes":{}}"#)
                    .utf8
            ))
        try handle.close()
        let appendDeadline = Date().addingTimeInterval(2)
        while repo.selectedPaneSpans.count != 2, Date() < appendDeadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(repo.selectedPaneSpans.map(\.name), ["replacement", "appended"])
    }

    // MARK: - Helpers

    private func createPane(
        tabDir: String, fileName: String,
        paneId: String, paneName: String, tabId: String, tabName: String
    ) throws {
        let dir = testDir.appendingPathComponent(tabDir, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let meta = """
            {"_type":"metadata","paneId":"\(paneId)","paneName":"\(paneName)","tabId":"\(tabId)","tabName":"\(tabName)","createdAt":"2026-01-01T00:00:00Z"}
            """
        try (meta + "\n").write(to: dir.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }
}
