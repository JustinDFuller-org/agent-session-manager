import Foundation
import MCP
import XCTest

@testable import AgentSessionManager

@MainActor
final class AgentControlResourceTests: XCTestCase {
    func testResourceURIParsingUsesStableIDs() {
        let id = UUID()

        XCTAssertEqual(AgentControlResourceURI("agent-session-manager://workspace"), .workspace)
        XCTAssertEqual(
            AgentControlResourceURI("agent-session-manager://panes/\(id.uuidString)"), .pane(id))
        XCTAssertEqual(
            AgentControlResourceURI("agent-session-manager://status-lines/pane/\(id.uuidString)"),
            .paneStatus(id))
        XCTAssertNil(AgentControlResourceURI("agent-session-manager://panes/not-an-id"))
        XCTAssertNil(AgentControlResourceURI("https://example.com/panes/\(id.uuidString)"))
    }

    func testScopeFilteringAndProfileEnvironmentRedaction() async throws {
        let fixture = makeFixture()
        defer { stopPanes(in: fixture.state) }

        let paneWorkspace = try JSONDecoder().decode(
            AgentControlWorkspaceSnapshot.self,
            from: Data(
                try await fixture.router.read(
                    uri: AgentControlResourceURI.workspace.rawValue, source: fixture.paneSource
                ).utf8))
        XCTAssertEqual(paneWorkspace.tabs.count, 1)
        XCTAssertEqual(paneWorkspace.tabs.first?.panes.map(\.id), [fixture.paneID])

        let tabWorkspace = try JSONDecoder().decode(
            AgentControlWorkspaceSnapshot.self,
            from: Data(
                try await fixture.router.read(
                    uri: AgentControlResourceURI.workspace.rawValue, source: fixture.tabSource
                ).utf8))
        XCTAssertEqual(tabWorkspace.tabs.count, 1)
        XCTAssertEqual(tabWorkspace.tabs.first?.panes.count, 2)

        let globalWorkspace = try JSONDecoder().decode(
            AgentControlWorkspaceSnapshot.self,
            from: Data(
                try await fixture.router.read(
                    uri: AgentControlResourceURI.workspace.rawValue, source: fixture.globalSource
                ).utf8))
        XCTAssertEqual(globalWorkspace.tabs.count, 2)

        do {
            _ = try await fixture.router.read(
                uri: AgentControlResourceURI.pane(fixture.otherPaneID).rawValue,
                source: fixture.paneSource)
            XCTFail("Pane scope must not read another pane")
        } catch {
            XCTAssertTrue(error is MCPError)
        }

        let profiles = try await fixture.router.read(
            uri: AgentControlResourceURI.profiles.rawValue, source: fixture.paneSource)
        XCTAssertTrue(profiles.contains("Secret Profile"))
        XCTAssertFalse(profiles.contains("secret-value"))
        XCTAssertFalse(profiles.contains("runtime-secret"))
    }

    func testResourceDiscoveryAndReadThroughMCPClient() async throws {
        let fixture = makeFixture()
        defer { stopPanes(in: fixture.state) }

        let tokenStore = AgentControlTokenStore()
        let application = AgentControlHTTPApplication(
            tokenStore: tokenStore,
            limits: .default,
            resourceRouter: fixture.router)
        let port = try await application.start()
        let credential = try tokenStore.register(source: fixture.globalSource, limits: .default)
        let endpoint = URL(string: "http://127.0.0.1:\(port)/mcp")!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = [
            "Authorization": "Bearer \(credential.bearerToken)"
        ]
        let transport = HTTPClientTransport(
            endpoint: endpoint,
            configuration: configuration)
        let client = Client(name: "AgentControlResourceTests", version: "1.0")
        defer {
            Task {
                await client.disconnect()
                await application.stop()
            }
        }

        try await client.connect(transport: transport)
        let resources = try await client.listResources()
        XCTAssertEqual(resources.resources.count, 9)
        let templates = try await client.listResourceTemplates()
        XCTAssertEqual(templates.templates.count, 4)
        let tools = try await client.listTools()
        XCTAssertEqual(tools.tools.count, 19)
        XCTAssertTrue(tools.tools.contains { $0.name == "profiles.create" })
        XCTAssertTrue(tools.tools.contains { $0.name == "harnesses.configure_cli_option" })

        let contents = try await client.readResource(uri: AgentControlResourceURI.workspace.rawValue)
        XCTAssertEqual(contents.count, 1)
        XCTAssertEqual(contents.first?.mimeType, "application/json")
        XCTAssertTrue(contents.first?.text?.contains(fixture.firstTabName) == true)

        for resource in [
            AgentControlResourceURI.diagnosticSummary,
            AgentControlResourceURI.diagnosticTraces,
            AgentControlResourceURI.diagnosticInvariants,
            AgentControlResourceURI.diagnosticLogs,
        ] {
            let diagnosticContents = try await client.readResource(uri: resource.rawValue)
            XCTAssertEqual(diagnosticContents.count, 1)
            XCTAssertEqual(diagnosticContents.first?.mimeType, "application/json")
            XCTAssertTrue(diagnosticContents.first?.text?.contains("availability") == true)
        }

        let traceQuery = try await client.callTool(
            name: "diagnostics.query_traces",
            arguments: ["limit": .int(1)])
        XCTAssertNil(traceQuery.isError)
        XCTAssertTrue(toolText(traceQuery.content)?.contains("records") == true)

        let logQuery = try await client.callTool(
            name: "diagnostics.query_logs",
            arguments: ["limit": .int(1)])
        XCTAssertNil(logQuery.isError)
        XCTAssertTrue(toolText(logQuery.content)?.contains("records") == true)

        let debugModeResult = try await client.callTool(
            name: "debug.set_mode",
            arguments: ["enabled": .bool(false)])
        XCTAssertNil(debugModeResult.isError)
    }

    func testResourceReadTelemetryContainsContextButNoPayload() async throws {
        let fixture = makeFixture()
        defer { stopPanes(in: fixture.state) }
        TracingService.shared.enableTestCapture()
        defer { TracingService.shared.resetForTesting() }

        _ = try await fixture.router.read(
            uri: AgentControlResourceURI.workspace.rawValue, source: fixture.paneSource)

        let event = try XCTUnwrap(
            TracingService.shared.recordedEventsForTesting.last {
                $0.name == "agent_control.resource.read"
            })
        XCTAssertEqual(event.attributes["pane.id"], fixture.paneID.uuidString)
        XCTAssertEqual(event.attributes["tab.id"], fixture.tabID.uuidString)
        XCTAssertEqual(event.attributes["result"], "success")
        XCTAssertNil(event.attributes["payload"])
        XCTAssertNil(event.attributes["token"])
    }

    private struct Fixture {
        let state: AppState
        let router: AgentControlResourceRouter
        let paneSource: AgentControlSource
        let tabSource: AgentControlSource
        let globalSource: AgentControlSource
        let tabID: UUID
        let paneID: UUID
        let otherPaneID: UUID
        let firstTabName: String
    }

    private func makeFixture() -> Fixture {
        let state = AppState()
        let settings = AppSettings()
        let profile = Profile(
            name: "Secret Profile",
            harness: .claude,
            envVars: [ProfileEnvVar(id: "API_KEY", isEnabled: true, value: "secret-value")])
        settings.profiles = [profile]

        let firstTab = Tab(name: "First Tab", directory: URL(filePath: "/tmp/first-repo"))
        let firstPane = firstTab.addPane(
            name: "First Pane",
            harness: .claude,
            worktreeDirectory: URL(filePath: "/tmp/first-worktree"),
            extraEnvVars: ["API_KEY": "runtime-secret"],
            profileID: profile.id,
            appSettings: settings)
        let secondPane = firstTab.addPane(
            name: "Second Pane",
            harness: .codex,
            worktreeDirectory: URL(filePath: "/tmp/second-worktree"),
            appSettings: settings)
        let secondTab = Tab(name: "Second Tab", directory: URL(filePath: "/tmp/second-repo"))
        _ = secondTab.addPane(
            name: "Other Pane",
            harness: .cursor,
            worktreeDirectory: URL(filePath: "/tmp/other-worktree"),
            appSettings: settings)
        state.tabs = [firstTab, secondTab]
        state.activeTabID = firstTab.id
        state.activePaneID = firstPane.id

        let router = AgentControlResourceRouter(appState: state, appSettings: settings)
        return Fixture(
            state: state,
            router: router,
            paneSource: AgentControlSource(
                paneID: firstPane.id, paneName: firstPane.name, tabID: firstTab.id,
                tabName: firstTab.name, scope: .pane),
            tabSource: AgentControlSource(
                paneID: firstPane.id, paneName: firstPane.name, tabID: firstTab.id,
                tabName: firstTab.name, scope: .tab),
            globalSource: AgentControlSource(
                paneID: firstPane.id, paneName: firstPane.name, tabID: firstTab.id,
                tabName: firstTab.name, scope: .global),
            tabID: firstTab.id,
            paneID: firstPane.id,
            otherPaneID: secondPane.id,
            firstTabName: firstTab.name)
    }

    private func stopPanes(in state: AppState) {
        for pane in state.tabs.flatMap(\.panes) {
            pane.terminalController?.terminate()
        }
    }

    private func toolText(_ content: [Tool.Content]) -> String? {
        guard case .text(let text, _, _) = content.first(where: { _ in true }) else { return nil }
        return text
    }
}
