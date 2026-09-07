import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import AgentSessionManager

final class PerPaneSpanExporterTests: XCTestCase {
    private var testDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("per-pane-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let testDir { try? FileManager.default.removeItem(at: testDir) }
        try await super.tearDown()
    }

    func testSpanWithPaneIdRoutesToPerPaneFile() throws {
        let exporter = PerPaneSpanExporter(tracesDirectory: testDir, maxBytesPerFile: 1_048_576)
        let span = makeSpan(
            name: "test.event",
            attrs: [
                "pane.id": "aaaa-bbbb-cccc-dddd",
                "pane.name": "mypane",
                "tab.id": "1111-2222-3333-4444",
                "tab.name": "mytab",
            ])
        exporter.export(spans: [span], explicitTimeout: nil)

        waitForWrite()

        let tabDirs = try FileManager.default.contentsOfDirectory(atPath: testDir.path)
        XCTAssertEqual(tabDirs.count, 1, "Expected exactly one tab directory")
        let tabDir = testDir.appendingPathComponent(tabDirs[0])
        let paneFiles = try FileManager.default.contentsOfDirectory(atPath: tabDir.path)
        XCTAssertEqual(paneFiles.count, 1, "Expected exactly one pane file")
        let paneFile = tabDir.appendingPathComponent(paneFiles[0])
        let content = try String(contentsOf: paneFile, encoding: .utf8)
        XCTAssertTrue(content.contains("test.event"))
    }

    func testSpanWithoutPaneIdGoesToGlobalFile() throws {
        let exporter = PerPaneSpanExporter(tracesDirectory: testDir, maxBytesPerFile: 1_048_576)
        let span = makeSpan(name: "global.event", attrs: [:])
        exporter.export(spans: [span], explicitTimeout: nil)

        waitForWrite()

        let globalFile =
            testDir
            .appendingPathComponent("_global")
            .appendingPathComponent("global.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: globalFile.path))
        let content = try String(contentsOf: globalFile, encoding: .utf8)
        XCTAssertTrue(content.contains("global.event"))
    }

    func testMetadataLineWrittenOnFirstWrite() throws {
        let exporter = PerPaneSpanExporter(tracesDirectory: testDir, maxBytesPerFile: 1_048_576)
        let paneId = "pane-uuid-1234"
        let span = makeSpan(
            name: "first.event",
            attrs: [
                "pane.id": paneId,
                "pane.name": "mypane",
                "tab.id": "tab-uuid-5678",
                "tab.name": "mytab",
            ])
        exporter.export(spans: [span], explicitTimeout: nil)
        waitForWrite()

        let file = findFirstJsonl(in: testDir)!
        let content = try String(contentsOf: file, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertGreaterThanOrEqual(lines.count, 2, "Expected metadata line + span line")
        let firstLine = lines[0]
        XCTAssertTrue(firstLine.contains("\"_type\":\"metadata\""))
        XCTAssertTrue(firstLine.contains(paneId))
    }

    func testMetadataLineWrittenOnlyOnce() throws {
        let exporter = PerPaneSpanExporter(tracesDirectory: testDir, maxBytesPerFile: 1_048_576)
        let attrs: [String: String] = [
            "pane.id": "pane-1", "pane.name": "p", "tab.id": "tab-1", "tab.name": "t",
        ]
        exporter.export(spans: [makeSpan(name: "e1", attrs: attrs)], explicitTimeout: nil)
        exporter.export(spans: [makeSpan(name: "e2", attrs: attrs)], explicitTimeout: nil)
        waitForWrite()

        let file = findFirstJsonl(in: testDir)!
        let content = try String(contentsOf: file, encoding: .utf8)
        let metadataCount = content.components(separatedBy: "\n")
            .filter { $0.contains("\"_type\":\"metadata\"") }
            .count
        XCTAssertEqual(metadataCount, 1, "Metadata should be written exactly once")
    }

    func testTrimIfNeededInvokedWhenFileExceedsLimit() throws {
        let smallMax = 300
        let file = testDir.appendingPathComponent("trim-test.jsonl")
        let longLine = String(repeating: "x", count: 80)
        let initial = Data((longLine + "\n" + longLine + "\n" + longLine + "\n").utf8)
        FileManager.default.createFile(atPath: file.path, contents: initial)

        let moreData = Data((longLine + "\n").utf8)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: moreData)
        try handle.close()

        PerPaneSpanExporter.trimIfNeeded(at: file, maxBytes: smallMax)

        let content = try String(contentsOf: file, encoding: .utf8)
        XCTAssertLessThanOrEqual(content.utf8.count, smallMax + 60)
    }

    func testGlobalMetadataLine() throws {
        let exporter = PerPaneSpanExporter(tracesDirectory: testDir, maxBytesPerFile: 1_048_576)
        exporter.export(spans: [makeSpan(name: "x", attrs: [:])], explicitTimeout: nil)
        waitForWrite()

        let globalFile = testDir.appendingPathComponent("_global").appendingPathComponent("global.jsonl")
        let content = try String(contentsOf: globalFile, encoding: .utf8)
        let firstLine = content.components(separatedBy: "\n").first!
        XCTAssertTrue(firstLine.contains("\"_type\":\"metadata\""))
        XCTAssertTrue(firstLine.contains("\"_global\""))
    }

    private func makeSpan(name: String, attrs: [String: String]) -> SpanData {
        let provider = TracerProviderBuilder().build()
        let tracer = provider.get(instrumentationName: "test", instrumentationVersion: nil)
        let builder = tracer.spanBuilder(spanName: name)
        let span = builder.startSpan()
        for (attrKey, attrValue) in attrs { span.setAttribute(key: attrKey, value: attrValue) }
        span.end()
        return (span as! RecordEventsReadableSpan).toSpanData()
    }

    private func waitForWrite() {
        let exp = XCTestExpectation(description: "async write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    private func findFirstJsonl(in dir: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            return nil
        }
        while let file = enumerator.nextObject() as? URL {
            if file.pathExtension == "jsonl" { return file }
        }
        return nil
    }
}
