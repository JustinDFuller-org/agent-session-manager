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
            name: "test", traceId: "abc", spanId: "def", parentSpanId: nil,
            startEpochMs: 1000, endEpochMs: 1250, attributes: [:]
        )
        XCTAssertEqual(span.durationMs, 250)
    }

    func testStoredSpanZeroDuration() {
        let span = StoredSpan(
            name: "instant", traceId: "a", spanId: "b", parentSpanId: nil,
            startEpochMs: 5000, endEpochMs: 5000, attributes: [:]
        )
        XCTAssertEqual(span.durationMs, 0)
    }

    func testStoredSpanAttributesArePreserved() {
        let span = StoredSpan(
            name: "test", traceId: "a", spanId: "b", parentSpanId: nil,
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

    // MARK: buildWaterfallRows

    func testBuildRowsRootSpanHasDepthZero() {
        let span = makeSpan(name: "root")
        let rows = buildWaterfallRows(from: [span])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].depth, 0)
    }

    func testBuildRowsFlattensHierarchyInDFSOrder() {
        let traceId = "trace-abc"
        let parentId = "span-parent"
        let parent = StoredSpan(
            name: "parent", traceId: traceId, spanId: parentId, parentSpanId: nil,
            startEpochMs: 100, endEpochMs: 300, attributes: [:]
        )
        let childA = StoredSpan(
            name: "child.a", traceId: traceId, spanId: "span-child-a", parentSpanId: parentId,
            startEpochMs: 110, endEpochMs: 200, attributes: [:]
        )
        let childB = StoredSpan(
            name: "child.b", traceId: traceId, spanId: "span-child-b", parentSpanId: parentId,
            startEpochMs: 210, endEpochMs: 290, attributes: [:]
        )
        let rows = buildWaterfallRows(from: [parent, childB, childA])
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0].span.name, "parent")
        XCTAssertEqual(rows[0].depth, 0)
        XCTAssertEqual(rows[1].span.name, "child.a")
        XCTAssertEqual(rows[1].depth, 1)
        XCTAssertEqual(rows[2].span.name, "child.b")
        XCTAssertEqual(rows[2].depth, 1)
    }

    func testBuildRowsOrphanedSpanBecomesRoot() {
        let span = StoredSpan(
            name: "orphan", traceId: "t1", spanId: "s1", parentSpanId: "nonexistent-parent",
            startEpochMs: 100, endEpochMs: 200, attributes: [:]
        )
        let rows = buildWaterfallRows(from: [span])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].depth, 0)
        XCTAssertEqual(rows[0].span.name, "orphan")
    }

    // MARK: buildTraceSummaries

    func testBuildTraceSummariesGroupsByTraceId() {
        let traceId = "trace-xyz"
        let root = StoredSpan(
            name: "pr.poll.cycle", traceId: traceId, spanId: "s-root", parentSpanId: nil,
            startEpochMs: 1000, endEpochMs: 2000, attributes: [:]
        )
        let child = StoredSpan(
            name: "pr.graphql.query", traceId: traceId, spanId: "s-child", parentSpanId: "s-root",
            startEpochMs: 1100, endEpochMs: 1900, attributes: [:]
        )
        let summaries = buildTraceSummaries(from: [root, child])
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].traceId, traceId)
        XCTAssertEqual(summaries[0].spanCount, 2)
        XCTAssertEqual(summaries[0].durationMs, 1000)
    }

    func testBuildTraceSummariesRootNameIsRootSpan() {
        let traceId = "trace-abc"
        let root = StoredSpan(
            name: "pr.poll.cycle", traceId: traceId, spanId: "s-root", parentSpanId: nil,
            startEpochMs: 1000, endEpochMs: 2000, attributes: [:]
        )
        let child = StoredSpan(
            name: "pr.graphql.query", traceId: traceId, spanId: "s-child", parentSpanId: "s-root",
            startEpochMs: 1100, endEpochMs: 1900, attributes: [:]
        )
        let summaries = buildTraceSummaries(from: [child, root])
        XCTAssertEqual(summaries[0].rootName, "pr.poll.cycle")
    }

    func testBuildTraceSummariesSortedNewestFirst() {
        let older = StoredSpan(
            name: "span.a", traceId: "trace-old", spanId: "s1", parentSpanId: nil,
            startEpochMs: 1000, endEpochMs: 1100, attributes: [:]
        )
        let newer = StoredSpan(
            name: "span.b", traceId: "trace-new", spanId: "s2", parentSpanId: nil,
            startEpochMs: 5000, endEpochMs: 5200, attributes: [:]
        )
        let summaries = buildTraceSummaries(from: [older, newer])
        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries[0].rootName, "span.b")
        XCTAssertEqual(summaries[1].rootName, "span.a")
    }

    func testBuildTraceSummariesDurationCoversAllSpans() {
        let traceId = "trace-dur"
        let root = StoredSpan(
            name: "root", traceId: traceId, spanId: "s-r", parentSpanId: nil,
            startEpochMs: 1000, endEpochMs: 1050, attributes: [:]
        )
        let longChild = StoredSpan(
            name: "child", traceId: traceId, spanId: "s-c", parentSpanId: "s-r",
            startEpochMs: 1010, endEpochMs: 3000, attributes: [:]
        )
        let summaries = buildTraceSummaries(from: [root, longChild])
        XCTAssertEqual(summaries[0].durationMs, 2000)
    }

    // MARK: Helpers

    private func makeSpan(name: String) -> StoredSpan {
        StoredSpan(
            name: name, traceId: UUID().uuidString, spanId: UUID().uuidString,
            parentSpanId: nil, startEpochMs: 1000, endEpochMs: 1100, attributes: [:]
        )
    }

    private func makeSpans(count: Int) -> [StoredSpan] {
        (0..<count).map { i in makeSpan(name: "span.\(i)") }
    }
}
