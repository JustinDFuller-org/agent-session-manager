import XCTest

@testable import AgentSessionManager

@MainActor
final class TracingServiceTests: XCTestCase {
    private var testTraceDir: URL!
    private var appSettings: AppSettings!

    override func setUp() async throws {
        try await super.setUp()
        let subdirectory = "tracing-test-\(UUID().uuidString)"
        PersistenceHelpers.overrideAppSupportSubdirectory = subdirectory
        testTraceDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(subdirectory, isDirectory: true)
            .appendingPathComponent("traces", isDirectory: true)
        try FileManager.default.createDirectory(at: testTraceDir, withIntermediateDirectories: true)
        appSettings = AppSettings()
        appSettings.debugModeEnabled = false
        TracingService.shared.configure(from: appSettings)
    }

    override func tearDown() async throws {
        appSettings.debugModeEnabled = false
        TracingService.shared.configure(from: appSettings)
        if let testTraceDir {
            try? FileManager.default.removeItem(at: testTraceDir.deletingLastPathComponent())
        }
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        try await super.tearDown()
    }

    func testNoOutputWhenDisabled() throws {
        TracingService.shared.record("test.event", attributes: ["key": "value"])
        // No files should exist in the test dir
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: testTraceDir.path)) ?? []
        XCTAssertTrue(contents.isEmpty)
    }

    func testRecordWritesFileWhenEnabled() throws {
        appSettings.debugModeEnabled = true
        TracingService.shared.configure(from: appSettings)

        // Emit a span with pane.id so it routes to a named pane file
        TracingService.shared.record(
            "test.event",
            attributes: [
                "foo": "bar",
                "pane.id": "test-pane-uuid",
                "pane.name": "testpane",
                "tab.id": "test-tab-uuid",
                "tab.name": "testtab",
            ])

        let expectation = XCTestExpectation(description: "trace file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Should have at least one JSONL file somewhere under testTraceDir
        var foundContent: String?
        let enumerator = FileManager.default.enumerator(at: testTraceDir, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            if file.pathExtension == "jsonl" {
                foundContent = try? String(contentsOf: file, encoding: .utf8)
                break
            }
        }
        XCTAssertNotNil(foundContent, "Expected a JSONL file under testTraceDir")
        XCTAssertTrue(foundContent?.contains("test.event") ?? false)
        XCTAssertTrue(foundContent?.contains("foo") ?? false)
        XCTAssertTrue(foundContent?.contains("bar") ?? false)
    }

    func testGlobalFileWrittenForSpansWithoutPaneId() throws {
        appSettings.debugModeEnabled = true
        TracingService.shared.configure(from: appSettings)

        TracingService.shared.record("global.event", attributes: ["key": "value"])

        let expectation = XCTestExpectation(description: "global file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        let globalFile =
            testTraceDir
            .appendingPathComponent("_global")
            .appendingPathComponent("global.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: globalFile.path))
        let content = try String(contentsOf: globalFile, encoding: .utf8)
        XCTAssertTrue(content.contains("global.event"))
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
        appSettings.debugModeEnabled = true
        TracingService.shared.configure(from: appSettings)
        XCTAssertTrue(TracingService.shared.isEnabled)

        appSettings.debugModeEnabled = false
        TracingService.shared.configure(from: appSettings)
        XCTAssertFalse(TracingService.shared.isEnabled)

        TracingService.shared.record("should.not.appear")
        let wait = XCTestExpectation(description: "give async writes time")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { wait.fulfill() }
        self.wait(for: [wait], timeout: 1)

        // No JSONL files should exist
        var foundFile = false
        let enumerator = FileManager.default.enumerator(at: testTraceDir, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            if file.pathExtension == "jsonl" {
                foundFile = true
                break
            }
        }
        XCTAssertFalse(foundFile)
    }
}
