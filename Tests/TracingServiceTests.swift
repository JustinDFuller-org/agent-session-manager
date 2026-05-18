import XCTest

@testable import AgentSessionManager

@MainActor
final class TracingServiceTests: XCTestCase {
    private var testTraceDir: URL!
    private var testTraceURL: URL!
    private var appSettings: AppSettings!

    override func setUp() async throws {
        try await super.setUp()
        testTraceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tracing-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testTraceDir, withIntermediateDirectories: true)
        testTraceURL = testTraceDir.appendingPathComponent("traces.jsonl")
        appSettings = AppSettings()
        appSettings.tracingEnabled = false
        TracingService.shared.configure(from: appSettings)
    }

    override func tearDown() async throws {
        appSettings.tracingEnabled = false
        TracingService.shared.configure(from: appSettings)
        if let testTraceDir {
            try? FileManager.default.removeItem(at: testTraceDir)
        }
        try await super.tearDown()
    }

    func testNoOutputWhenDisabled() throws {
        TracingService.shared.record("test.event", attributes: ["key": "value"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: testTraceURL.path))
    }

    func testRecordWritesFileWhenEnabled() throws {
        appSettings.tracingEnabled = true
        appSettings.tracingOutputTarget = .file
        appSettings.tracingFilePath = testTraceURL.path
        TracingService.shared.configure(from: appSettings)

        TracingService.shared.record("test.event", attributes: ["foo": "bar"])

        let expectation = XCTestExpectation(description: "trace file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testTraceURL.path))
        let content = try String(contentsOf: testTraceURL, encoding: .utf8)
        XCTAssertTrue(content.contains("test.event"))
        XCTAssertTrue(content.contains("foo"))
        XCTAssertTrue(content.contains("bar"))
    }

    func testWithSpanSyncExecutesBody() throws {
        var bodyExecuted = false
        let result = TracingService.shared.withSpan("test.span") {
            bodyExecuted = true
            return 42
        }
        XCTAssertTrue(bodyExecuted)
        XCTAssertEqual(result, 42)
    }

    func testWithSpanAsyncExecutesBody() async throws {
        var bodyExecuted = false
        let result = await TracingService.shared.withSpan("test.span.async") {
            bodyExecuted = true
            return "hello"
        }
        XCTAssertTrue(bodyExecuted)
        XCTAssertEqual(result, "hello")
    }

    func testReconfigureDisablesOutput() throws {
        appSettings.tracingEnabled = true
        appSettings.tracingOutputTarget = .file
        appSettings.tracingFilePath = testTraceURL.path
        TracingService.shared.configure(from: appSettings)
        XCTAssertTrue(TracingService.shared.isEnabled)

        appSettings.tracingEnabled = false
        TracingService.shared.configure(from: appSettings)
        XCTAssertFalse(TracingService.shared.isEnabled)

        TracingService.shared.record("should.not.appear")
        let wait = XCTestExpectation(description: "give async writes time")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { wait.fulfill() }
        self.wait(for: [wait], timeout: 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testTraceURL.path))
    }

    func testFileSpanExporterTrimming() throws {
        let smallURL = testTraceDir.appendingPathComponent("small-traces.jsonl")
        let exporter = FileSpanExporter(fileURL: smallURL, maxBytes: 200)

        let longLine = String(repeating: "x", count: 80)
        let data = Data((longLine + "\n" + longLine + "\n" + longLine + "\n").utf8)

        let handle = FileHandle.nullDevice
        _ = handle

        FileManager.default.createFile(atPath: smallURL.path, contents: data)

        let moreData = Data((longLine + "\n").utf8)
        let writeHandle = try FileHandle(forWritingTo: smallURL)
        try writeHandle.seekToEnd()
        try writeHandle.write(contentsOf: moreData)
        try writeHandle.close()

        let expectation = XCTestExpectation(description: "file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)

        let content = try String(contentsOf: smallURL, encoding: .utf8)
        XCTAssertLessThanOrEqual(content.utf8.count, 450)
        _ = exporter
    }
}
