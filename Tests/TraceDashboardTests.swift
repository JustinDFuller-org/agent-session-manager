import XCTest

@testable import AgentSessionManager

@MainActor
final class TraceDashboardTests: XCTestCase {

    private var appSettings: AppSettings!

    override func setUp() async throws {
        try await super.setUp()
        TraceStore.shared.clear()
        TraceStore.shared.maxSpans = 500
        appSettings = AppSettings()
        appSettings.tracingEnabled = false
        TracingService.shared.configure(from: appSettings)
    }

    override func tearDown() async throws {
        appSettings.tracingEnabled = false
        TracingService.shared.configure(from: appSettings)
        TraceStore.shared.clear()
        TraceStore.shared.maxSpans = 500
        try await super.tearDown()
    }

    // MARK: TraceStore

    func testAppendStoresSpans() {
        TraceStore.shared.append(contentsOf: makeSpans(count: 3))
        XCTAssertEqual(TraceStore.shared.spans.count, 3)
    }

    func testAppendRespectMaxSpansCap() {
        TraceStore.shared.maxSpans = 5
        TraceStore.shared.append(contentsOf: makeSpans(count: 10))
        XCTAssertEqual(TraceStore.shared.spans.count, 5)
    }

    func testAppendDropsOldestWhenOverLimit() {
        TraceStore.shared.maxSpans = 3
        let first = makeSpan(name: "span.first")
        let second = makeSpan(name: "span.second")
        TraceStore.shared.append(contentsOf: [first, second])
        TraceStore.shared.append(contentsOf: makeSpans(count: 3))
        XCTAssertEqual(TraceStore.shared.spans.count, 3)
        XCTAssertFalse(TraceStore.shared.spans.contains(where: { $0.name == "span.first" }))
        XCTAssertFalse(TraceStore.shared.spans.contains(where: { $0.name == "span.second" }))
    }

    func testClearEmptiesSpans() {
        TraceStore.shared.append(contentsOf: makeSpans(count: 5))
        XCTAssertFalse(TraceStore.shared.spans.isEmpty)
        TraceStore.shared.clear()
        XCTAssertTrue(TraceStore.shared.spans.isEmpty)
    }

    func testMaxSpansTrimsOnNextAppend() {
        TraceStore.shared.append(contentsOf: makeSpans(count: 10))
        XCTAssertEqual(TraceStore.shared.spans.count, 10)
        TraceStore.shared.maxSpans = 4
        TraceStore.shared.append(contentsOf: makeSpans(count: 1))
        XCTAssertEqual(TraceStore.shared.spans.count, 4)
    }

    // MARK: StoredSpan

    func testStoredSpanDurationMs() {
        let span = StoredSpan(
            name: "test", traceId: "abc", spanId: "def",
            startEpochMs: 1000, endEpochMs: 1250, attributes: [:]
        )
        XCTAssertEqual(span.durationMs, 250)
    }

    func testStoredSpanZeroDuration() {
        let span = StoredSpan(
            name: "instant", traceId: "a", spanId: "b",
            startEpochMs: 5000, endEpochMs: 5000, attributes: [:]
        )
        XCTAssertEqual(span.durationMs, 0)
    }

    func testStoredSpanAttributesArePreserved() {
        let span = StoredSpan(
            name: "test", traceId: "a", spanId: "b",
            startEpochMs: 0, endEpochMs: 10,
            attributes: ["key1": "value1", "key2": "value2"]
        )
        XCTAssertEqual(span.attributes["key1"], "value1")
        XCTAssertEqual(span.attributes["key2"], "value2")
    }

    func testStoredSpanHasUniqueIDs() {
        let a = makeSpan(name: "same.name")
        let b = makeSpan(name: "same.name")
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: MemorySpanExporter (via TracingService)

    func testMemorySpanExporterPopulatesStoreWhenTracingEnabled() {
        appSettings.tracingEnabled = true
        appSettings.tracingOutputTarget = .stdout
        TracingService.shared.configure(from: appSettings)

        TracingService.shared.record("dashboard.test.event")

        let expectation = XCTestExpectation(description: "span dispatched to main")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { expectation.fulfill() }
        wait(for: [expectation], timeout: 2)

        XCTAssertTrue(TraceStore.shared.spans.contains(where: { $0.name == "dashboard.test.event" }))
    }

    func testMemorySpanExporterNotPopulatedWhenTracingDisabled() {
        TracingService.shared.record("dashboard.disabled.event")

        let expectation = XCTestExpectation(description: "wait for any dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { expectation.fulfill() }
        wait(for: [expectation], timeout: 2)

        XCTAssertFalse(TraceStore.shared.spans.contains(where: { $0.name == "dashboard.disabled.event" }))
    }

    func testMemorySpanExporterReturnsSuccess() {
        let exporter = MemorySpanExporter()
        let result = exporter.export(spans: [], explicitTimeout: nil)
        XCTAssertEqual(result, .success)
    }

    // MARK: Helpers

    private func makeSpan(name: String) -> StoredSpan {
        StoredSpan(
            name: name, traceId: UUID().uuidString, spanId: UUID().uuidString,
            startEpochMs: 1000, endEpochMs: 1100, attributes: [:]
        )
    }

    private func makeSpans(count: Int) -> [StoredSpan] {
        (0..<count).map { i in makeSpan(name: "span.\(i)") }
    }
}
