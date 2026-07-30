import Foundation
import MCP
import XCTest

@testable import AgentSessionManager

@MainActor
final class AgentControlDiagnosticsTests: XCTestCase {
    private var supportDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-control-diagnostics-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        PersistenceHelpers.overrideAppSupportSubdirectory = supportDirectory.lastPathComponent
    }

    override func tearDown() async throws {
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        try? FileManager.default.removeItem(at: supportDirectory)
        try await super.tearDown()
    }

    func testDiagnosticURIParsingUsesStableDiagnosticPaths() {
        XCTAssertEqual(
            AgentControlResourceURI("agent-session-manager://diagnostics/summary"), .diagnosticSummary)
        XCTAssertEqual(
            AgentControlResourceURI("agent-session-manager://diagnostics/traces"), .diagnosticTraces)
        XCTAssertEqual(
            AgentControlResourceURI("agent-session-manager://diagnostics/invariants"), .diagnosticInvariants)
        XCTAssertEqual(
            AgentControlResourceURI("agent-session-manager://diagnostics/logs"), .diagnosticLogs)
        XCTAssertNil(AgentControlResourceURI("agent-session-manager://diagnostics/unknown"))
    }

    func testDiagnosticResourceQueryUsesBoundedTimeWindowAndLimit() throws {
        let query = try AgentControlDiagnosticResourceQuery(queryItems: [
            URLQueryItem(name: "sinceEpochMs", value: "10"),
            URLQueryItem(name: "untilEpochMs", value: "20"),
            URLQueryItem(name: "limit", value: "999"),
        ])

        XCTAssertEqual(query.sinceEpochMs, 10)
        XCTAssertEqual(query.untilEpochMs, 20)
        XCTAssertEqual(query.limit, 999)

        let resolved = try AgentControlDiagnosticQuery(
            sinceEpochMs: query.sinceEpochMs,
            untilEpochMs: query.untilEpochMs,
            limit: query.limit
        ).resolved(defaultLimit: 20, maximumLimit: 50)
        XCTAssertEqual(resolved.limit, 50)
        XCTAssertEqual(resolved.sinceEpochMs, 10)
        XCTAssertEqual(resolved.untilEpochMs, 20)
    }

    func testTraceDiagnosticsUseMetadataAndRedactSensitiveAttributes() async throws {
        let fixture = makeFixture()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let traces = supportDirectory.appending(path: "traces/sanitized-tab/sanitized-pane.jsonl")
        try FileManager.default.createDirectory(
            at: traces.deletingLastPathComponent(), withIntermediateDirectories: true)
        let metadata = """
            {"_type":"metadata","paneId":"\(fixture.paneID.uuidString)","paneName":"Pane","tabId":"\(fixture.tabID.uuidString)","tabName":"Tab","createdAt":"2026-07-23T00:00:00Z"}
            {"name":"diagnostic.event","traceId":"trace","spanId":"span","startEpochMs":\(now - 1000),"endEpochMs":\(now),"durationMs":1000,"attributes":{"safe":"visible","token":"hidden","path":"/private/path"}}
            --- [truncated older trace entries] ---
            malformed
            """
        try metadata.write(to: traces, atomically: true, encoding: .utf8)

        let result = try decodeTraceResult(
            try await fixture.router.read(
                uri: AgentControlResourceURI.diagnosticTraces.rawValue, source: fixture.paneSource))
        XCTAssertEqual(result.files.first?.paneID, fixture.paneID.uuidString)
        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.records.first?.attributes["safe"], "visible")
        XCTAssertNil(result.records.first?.attributes["token"])
        XCTAssertNil(result.records.first?.attributes["path"])
        XCTAssertTrue(result.metadata.sourceTruncated)
        XCTAssertEqual(result.metadata.malformedLines, 1)
    }

    func testTraceResourceReadAppliesQueryParameters() async throws {
        let fixture = makeFixture()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let metadata = [
            "paneId": fixture.paneID.uuidString, "paneName": "Pane",
            "tabId": fixture.tabID.uuidString, "tabName": "Tab",
        ]
        try writeTrace(path: "traces/query/old.jsonl", metadata: metadata, eventName: "old.event", start: now - 2_000)
        try writeTrace(path: "traces/query/new.jsonl", metadata: metadata, eventName: "new.event", start: now)

        let uri = "\(AgentControlResourceURI.diagnosticTraces.rawValue)?limit=1&sinceEpochMs=\(now - 1_000)"
        let result = try decodeTraceResult(try await fixture.router.read(uri: uri, source: fixture.paneSource))

        XCTAssertEqual(result.records.map(\.name), ["new.event"])
        XCTAssertEqual(result.metadata.query.limit, 1)
        XCTAssertEqual(result.metadata.query.sinceEpochMs, now - 1_000)
    }

    func testTraceDiagnosticsRespectPaneAndGlobalScope() async throws {
        let fixture = makeFixture()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        try writeTrace(
            path: "traces/tab/pane.jsonl",
            metadata: [
                "paneId": fixture.paneID.uuidString, "paneName": "Pane",
                "tabId": fixture.tabID.uuidString, "tabName": "Tab",
            ],
            eventName: "pane.event", start: now)
        try writeTrace(
            path: "traces/_global/global.jsonl",
            metadata: ["paneId": "_global", "paneName": "global", "tabId": "_global", "tabName": "_global"],
            eventName: "global.event", start: now)

        let paneResult = try decodeTraceResult(
            try await fixture.router.read(
                uri: AgentControlResourceURI.diagnosticTraces.rawValue, source: fixture.paneSource))
        XCTAssertEqual(paneResult.records.map(\.name), ["pane.event"])

        let globalResult = try decodeTraceResult(
            try await fixture.router.read(
                uri: AgentControlResourceURI.diagnosticTraces.rawValue, source: fixture.globalSource))
        XCTAssertEqual(Set(globalResult.records.map(\.name)), ["pane.event", "global.event"])
    }

    func testTraceQueriesApplyWindowEventFilterAndLimit() async throws {
        let fixture = makeFixture()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        try writeTrace(
            path: "traces/filter/pane.jsonl",
            metadata: [
                "paneId": fixture.paneID.uuidString, "paneName": "Pane",
                "tabId": fixture.tabID.uuidString, "tabName": "Tab",
            ],
            eventName: "old.event", start: now - 5_000)
        try writeTrace(
            path: "traces/filter/pane-2.jsonl",
            metadata: [
                "paneId": fixture.paneID.uuidString, "paneName": "Pane",
                "tabId": fixture.tabID.uuidString, "tabName": "Tab",
            ],
            eventName: "target.event", start: now - 1_000)

        let result = try await fixture.router.callTool(
            name: "diagnostics_query_traces",
            arguments: [
                "sinceEpochMs": .int(Int(now - 2_000)),
                "untilEpochMs": .int(Int(now)),
                "limit": .int(1),
                "eventNames": .array([.string("target.event")]),
            ],
            source: fixture.paneSource)
        let decoded = try decodeTraceResult(try textContent(result))
        XCTAssertEqual(decoded.records.map { $0.name }, ["target.event"])
        XCTAssertEqual(decoded.metadata.returnedCount, 1)
        XCTAssertFalse(decoded.metadata.limitTruncated)
    }

    func testDiagnosticSelectorsRejectMalformedUUIDs() async throws {
        let fixture = makeFixture()
        do {
            _ = try await fixture.router.callTool(
                name: "diagnostics_query_traces",
                arguments: ["paneID": .string("not-a-uuid")],
                source: fixture.globalSource)
            XCTFail("Malformed selectors must be rejected")
        } catch {
            XCTAssertTrue(error is MCPError)
        }
    }

    func testDiagnosticsRemainReadableWhenDebugModeIsDisabled() async throws {
        let fixture = makeFixture()
        fixture.settings.debugModeEnabled = false
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        try writeTrace(
            path: "traces/disabled/pane.jsonl",
            metadata: [
                "paneId": fixture.paneID.uuidString, "paneName": "Pane",
                "tabId": fixture.tabID.uuidString, "tabName": "Tab",
            ],
            eventName: "existing.event", start: now)

        let result = try await fixture.router.read(
            uri: AgentControlResourceURI.diagnosticTraces.rawValue, source: fixture.paneSource)
        let decoded = try decodeTraceResult(result)
        XCTAssertFalse(decoded.availability.debugModeEnabled)
        XCTAssertEqual(decoded.records.map(\.name), ["existing.event"])
    }

    func testEmptyInvariantResourceIsReadableAndReportsCaptureSeparately() async throws {
        let fixture = makeFixture()
        fixture.settings.debugModeEnabled = true

        let result = try await fixture.router.read(
            uri: AgentControlResourceURI.diagnosticInvariants.rawValue, source: fixture.paneSource)
        let decoded = try decodeInvariantResult(result)

        XCTAssertTrue(decoded.records.isEmpty)
        XCTAssertTrue(decoded.availability.invariantsReadable)
        XCTAssertTrue(decoded.availability.invariantsCapturing)
    }

    func testDiagnosticSummaryDescribesCurrentScopeAndGlobalCapabilities() async throws {
        let fixture = makeFixture()
        let data = try await fixture.router.read(
            uri: AgentControlResourceURI.diagnosticSummary.rawValue, source: fixture.paneSource)
        let summary = try JSONDecoder().decode(AgentControlDiagnosticSummary.self, from: Data(data.utf8))

        XCTAssertEqual(summary.currentScope, .pane)
        XCTAssertTrue(summary.globalOnlyResources.contains(AgentControlResourceURI.harnesses.rawValue))
        XCTAssertTrue(summary.globalOnlyTools.contains("debug_set_mode"))
    }

    func testDiagnosticQueryTelemetryIncludesOutcomeAndScopeContext() async throws {
        let fixture = makeFixture()
        TracingService.shared.enableTestCapture()
        defer { TracingService.shared.resetForTesting() }

        _ = try await fixture.router.read(
            uri: AgentControlResourceURI.diagnosticTraces.rawValue, source: fixture.paneSource)

        let event = try XCTUnwrap(
            TracingService.shared.recordedEventsForTesting.last {
                $0.name == "agent_control.diagnostic.query"
            })
        XCTAssertEqual(event.attributes["result"], "success")
        XCTAssertEqual(event.attributes["pane.id"], fixture.paneID.uuidString)
        XCTAssertEqual(event.attributes["tab.id"], fixture.tabID.uuidString)
        XCTAssertNil(event.attributes["token"])
    }

    func testDiagnosticQueryObservesCancellation() async throws {
        let fixture = makeFixture()
        let traces = supportDirectory.appending(path: "traces/cancel/pane.jsonl")
        try FileManager.default.createDirectory(
            at: traces.deletingLastPathComponent(), withIntermediateDirectories: true)
        let metadata = String(
            decoding: try JSONSerialization.data(withJSONObject: [
                "_type": "metadata", "paneId": fixture.paneID.uuidString, "paneName": "Pane",
                "tabId": fixture.tabID.uuidString, "tabName": "Tab", "createdAt": "2026-07-23T00:00:00Z",
            ]),
            as: UTF8.self)
        let event = String(
            decoding: try JSONSerialization.data(withJSONObject: [
                "name": "cancel.event", "traceId": "trace", "spanId": "span",
                "startEpochMs": 1, "endEpochMs": 1, "durationMs": 0, "attributes": [:],
            ]),
            as: UTF8.self)
        try (metadata + "\n" + String(repeating: event + "\n", count: 5_000))
            .write(to: traces, atomically: true, encoding: .utf8)

        let task = Task {
            try await fixture.router.read(
                uri: AgentControlResourceURI.diagnosticTraces.rawValue, source: fixture.paneSource)
        }
        await Task.yield()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled diagnostic query must not return a result")
        } catch is CancellationError {
            XCTAssertTrue(true)
        }
    }

    func testInvariantDiagnosticsPreserveOccurrencesAndRedactContext() async throws {
        let fixture = makeFixture()
        let directory = supportDirectory.appending(path: "invariants")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let violation = InvariantViolation(
            invariant: .statusLineLinesSource,
            context: [
                "pane.id": fixture.paneID.uuidString,
                "tab.id": fixture.tabID.uuidString,
                "reported_added": "4",
                "secret": "hidden",
                "path": "/private/path",
            ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let metadata = "{\"_type\":\"metadata\",\"schemaVersion\":1}\n"
        let content = metadata + String(decoding: try encoder.encode(violation), as: UTF8.self) + "\n"
        try content.write(to: directory.appending(path: "invariants.jsonl"), atomically: true, encoding: .utf8)

        let result = try decodeInvariantResult(
            try await fixture.router.read(
                uri: AgentControlResourceURI.diagnosticInvariants.rawValue, source: fixture.paneSource))
        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.records.first?.context["reported_added"], "4")
        XCTAssertNil(result.records.first?.context["secret"])
        XCTAssertNil(result.records.first?.context["path"])
    }

    func testGlobalScopeCanChangeDebugModeAndPersistsIt() async throws {
        let fixture = makeFixture()
        let router = fixture.router
        let result = try await router.callTool(
            name: "debug_set_mode",
            arguments: ["enabled": .bool(true)],
            source: fixture.globalSource)
        XCTAssertNil(result.isError)
        XCTAssertTrue(
            SettingsPersistence.load(SettingsPersistence.DebugSettings.self, from: "debug-settings.json")?.enabled
                == true)
        XCTAssertTrue(fixture.settings.debugModeEnabled)

        _ = try await router.callTool(
            name: "debug_set_mode",
            arguments: ["enabled": .bool(false)],
            source: fixture.globalSource)
    }

    func testLowerScopeCannotChangeDebugMode() async throws {
        let fixture = makeFixture()
        do {
            _ = try await fixture.router.callTool(
                name: "debug_set_mode",
                arguments: ["enabled": .bool(true)],
                source: fixture.paneSource)
            XCTFail("Pane scope must not change Debug Mode")
        } catch {
            XCTAssertTrue(error is MCPError)
        }
    }

    private struct Fixture {
        let state: AppState
        let settings: AppSettings
        let router: AgentControlResourceRouter
        let paneSource: AgentControlSource
        let globalSource: AgentControlSource
        let tabID: UUID
        let paneID: UUID
    }

    private func makeFixture() -> Fixture {
        let state = AppState()
        let settings = AppSettings()
        let tab = Tab(name: "Tab", directory: URL(filePath: "/tmp/repo"))
        let pane = tab.addPane(
            name: "Pane", harness: .claude,
            worktreeDirectory: URL(filePath: "/tmp/worktree"), appSettings: settings)
        state.tabs = [tab]
        let router = AgentControlResourceRouter(appState: state, appSettings: settings)
        return Fixture(
            state: state,
            settings: settings,
            router: router,
            paneSource: AgentControlSource(
                paneID: pane.id, paneName: pane.name, tabID: tab.id, tabName: tab.name, scope: .pane),
            globalSource: AgentControlSource(
                paneID: pane.id, paneName: pane.name, tabID: tab.id, tabName: tab.name, scope: .global),
            tabID: tab.id,
            paneID: pane.id)
    }

    private func writeTrace(path: String, metadata: [String: String], eventName: String, start: Int64) throws {
        let url = supportDirectory.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let metadataJSON = try JSONSerialization.data(withJSONObject: [
            "_type": "metadata", "createdAt": "2026-07-23T00:00:00Z",
            "paneId": metadata["paneId"] ?? "_global", "paneName": metadata["paneName"] ?? "global",
            "tabId": metadata["tabId"] ?? "_global", "tabName": metadata["tabName"] ?? "global",
        ])
        let spanJSON = try JSONSerialization.data(withJSONObject: [
            "name": eventName, "traceId": "trace", "spanId": "span",
            "startEpochMs": start, "endEpochMs": start, "durationMs": 0, "attributes": [:],
        ])
        let content =
            String(decoding: metadataJSON, as: UTF8.self) + "\n"
            + String(decoding: spanJSON, as: UTF8.self) + "\n"
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func decodeTraceResult(_ string: String) throws -> AgentControlTraceQueryResult {
        try JSONDecoder().decode(AgentControlTraceQueryResult.self, from: Data(string.utf8))
    }

    private func decodeInvariantResult(_ string: String) throws -> AgentControlInvariantQueryResult {
        try JSONDecoder().decode(AgentControlInvariantQueryResult.self, from: Data(string.utf8))
    }

    private func textContent(_ result: CallTool.Result) throws -> String {
        guard case .text(let text, _, _) = result.content.first else {
            throw NSError(domain: "AgentControlDiagnosticsTests", code: 1)
        }
        return text
    }
}
