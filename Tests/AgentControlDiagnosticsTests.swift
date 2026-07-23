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
            .appending(path: "agent-control-diagnostics-tests-(UUID().uuidString)")
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

    func testTraceDiagnosticsUseMetadataAndRedactSensitiveAttributes() throws {
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
            fixture.router.read(uri: AgentControlResourceURI.diagnosticTraces.rawValue, source: fixture.paneSource))
        XCTAssertEqual(result.files.first?.paneID, fixture.paneID.uuidString)
        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.records.first?.attributes["safe"], "visible")
        XCTAssertNil(result.records.first?.attributes["token"])
        XCTAssertNil(result.records.first?.attributes["path"])
        XCTAssertTrue(result.metadata.sourceTruncated)
        XCTAssertEqual(result.metadata.malformedLines, 1)
    }

    func testTraceDiagnosticsRespectPaneAndGlobalScope() throws {
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
            fixture.router.read(uri: AgentControlResourceURI.diagnosticTraces.rawValue, source: fixture.paneSource))
        XCTAssertEqual(paneResult.records.map(\.name), ["pane.event"])

        let globalResult = try decodeTraceResult(
            fixture.router.read(uri: AgentControlResourceURI.diagnosticTraces.rawValue, source: fixture.globalSource))
        XCTAssertEqual(Set(globalResult.records.map(\.name)), ["pane.event", "global.event"])
    }

    func testInvariantDiagnosticsPreserveOccurrencesAndRedactContext() throws {
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
            fixture.router.read(uri: AgentControlResourceURI.diagnosticInvariants.rawValue, source: fixture.paneSource))
        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.records.first?.context["reported_added"], "4")
        XCTAssertNil(result.records.first?.context["secret"])
        XCTAssertNil(result.records.first?.context["path"])
    }

    func testGlobalScopeCanChangeDebugModeAndPersistsIt() throws {
        let fixture = makeFixture()
        let router = fixture.router
        let result = try router.callTool(
            name: "debug.set_mode",
            arguments: ["enabled": .bool(true)],
            source: fixture.globalSource)
        XCTAssertNil(result.isError)
        XCTAssertTrue(
            SettingsPersistence.load(SettingsPersistence.DebugSettings.self, from: "debug-settings.json")?.enabled
                == true)
        XCTAssertTrue(fixture.settings.debugModeEnabled)

        _ = try router.callTool(
            name: "debug.set_mode",
            arguments: ["enabled": .bool(false)],
            source: fixture.globalSource)
    }

    func testLowerScopeCannotChangeDebugMode() throws {
        let fixture = makeFixture()
        XCTAssertThrowsError(
            try fixture.router.callTool(
                name: "debug.set_mode",
                arguments: ["enabled": .bool(true)],
                source: fixture.paneSource))
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
}
