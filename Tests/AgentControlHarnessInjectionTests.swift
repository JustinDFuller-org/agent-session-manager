import Foundation
import XCTest

@testable import AgentSessionManager

final class AgentControlHarnessInjectionTests: XCTestCase {
    private let endpoint = URL(string: "http://127.0.0.1:43123/mcp")!
    private let tokenKey = "AGENT_SESSION_MANAGER_MCP_TOKEN"

    func testClaudeUsesRuntimeEnvironmentReferenceAndNeverEmbedsToken() throws {
        let context = AgentControlHarnessLaunchContext(
            endpoint: endpoint,
            tokenEnvironmentKey: tokenKey,
            commandArguments: ["claude", "--settings", "/tmp/settings.json"],
            environment: ["AGENT_SESSION_MANAGER_MCP_TOKEN=runtime-secret"]
        )

        let prepared = try ClaudeAgentControlAdapter().prepare(context)
        XCTAssertTrue(prepared.commandArguments.contains("--mcp-config"))
        XCTAssertTrue(prepared.commandArguments.contains { $0.contains("127.0.0.1:43123") })
        XCTAssertTrue(prepared.commandArguments.contains { $0.contains("${AGENT_SESSION_MANAGER_MCP_TOKEN}") })
        XCTAssertFalse(prepared.commandArguments.contains { $0.contains("runtime-secret") })
        XCTAssertEqual(prepared.environment, context.environment)
    }

    func testCodexUsesCLIOverridesAndTokenEnvironmentName() throws {
        let context = AgentControlHarnessLaunchContext(
            endpoint: endpoint,
            tokenEnvironmentKey: tokenKey,
            commandArguments: ["codex"],
            environment: []
        )

        let prepared = try CodexAgentControlAdapter().prepare(context)
        XCTAssertTrue(
            prepared.commandArguments.contains(
                "mcp_servers.agent_session_manager.url=\"\(endpoint.absoluteString)\""))
        XCTAssertTrue(
            prepared.commandArguments.contains(
                "mcp_servers.agent_session_manager.bearer_token_env_var=\"\(tokenKey)\""))
        XCTAssertTrue(prepared.commandArguments.contains("mcp_servers.agent_session_manager.enabled=true"))
    }

    func testOpenCodeMergesRemoteServerIntoExistingInlineConfig() throws {
        let existing =
            "{\"share\":\"manual\",\"permission\":{\"*\":\"ask\"},\"mcp\":{\"local-server\":{\"type\":\"remote\",\"url\":\"http://127.0.0.1:9999/mcp\"}}}"
        let context = AgentControlHarnessLaunchContext(
            endpoint: endpoint,
            tokenEnvironmentKey: tokenKey,
            commandArguments: ["opencode"],
            environment: ["OPENCODE_CONFIG_CONTENT=\(existing)", "OPENCODE_PERMISSION={\"*\":\"ask\"}"]
        )

        let prepared = try OpenCodeAgentControlAdapter().prepare(context)
        let value = prepared.environment.first { $0.hasPrefix("OPENCODE_CONFIG_CONTENT=") }!
        let config =
            try JSONSerialization.jsonObject(
                with: Data(value.dropFirst("OPENCODE_CONFIG_CONTENT=".count).utf8))
            as! [String: Any]
        let mcp = (config["mcp"] as! [String: Any])["agent-session-manager"] as! [String: Any]
        XCTAssertEqual(mcp["type"] as? String, "remote")
        XCTAssertEqual(mcp["oauth"] as? Bool, false)
        XCTAssertTrue((mcp["headers"] as! [String: String])["Authorization"]!.contains(tokenKey))
        let existingMCP = (config["mcp"] as! [String: Any])["local-server"] as! [String: Any]
        XCTAssertEqual(existingMCP["url"] as? String, "http://127.0.0.1:9999/mcp")
        XCTAssertEqual(config["share"] as? String, "manual")
    }

    func testOpenCodeRejectsMissingOrMalformedConfiguration() {
        let missing = AgentControlHarnessLaunchContext(
            endpoint: endpoint,
            tokenEnvironmentKey: tokenKey,
            commandArguments: ["opencode"],
            environment: [])
        XCTAssertThrowsError(try OpenCodeAgentControlAdapter().prepare(missing))

        let malformed = AgentControlHarnessLaunchContext(
            endpoint: endpoint,
            tokenEnvironmentKey: tokenKey,
            commandArguments: ["opencode"],
            environment: ["OPENCODE_CONFIG_CONTENT=not-json"])
        XCTAssertThrowsError(try OpenCodeAgentControlAdapter().prepare(malformed))

        let invalidMCP = AgentControlHarnessLaunchContext(
            endpoint: endpoint,
            tokenEnvironmentKey: tokenKey,
            commandArguments: ["opencode"],
            environment: ["OPENCODE_CONFIG_CONTENT={\"mcp\":true}"])
        XCTAssertThrowsError(try OpenCodeAgentControlAdapter().prepare(invalidMCP))
    }

    func testCursorUsesPrivatePluginDirectoryAndRuntimeTokenReference() throws {
        let paneID = UUID()
        let context = AgentControlHarnessLaunchContext(
            endpoint: endpoint,
            tokenEnvironmentKey: tokenKey,
            commandArguments: ["agent"],
            environment: ["\(tokenKey)=runtime-secret"],
            paneID: paneID
        )

        let prepared = try CursorAgentControlAdapter().prepare(context)
        defer { CursorAgentControlPlugin.remove(directory: prepared.cursorPluginDirectory) }

        let directory = try XCTUnwrap(prepared.cursorPluginDirectory)
        XCTAssertEqual(prepared.commandArguments.suffix(2), ["--plugin-dir", directory.path])
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appending(path: "mcp.json").path))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: directory.appending(path: ".cursor-plugin/plugin.json").path))

        let mcpData = try Data(contentsOf: directory.appending(path: "mcp.json"))
        let mcp = try XCTUnwrap(JSONSerialization.jsonObject(with: mcpData) as? [String: Any])
        let servers = try XCTUnwrap(mcp["mcpServers"] as? [String: Any])
        let server = try XCTUnwrap(servers.values.first as? [String: Any])
        XCTAssertEqual(server["url"] as? String, endpoint.absoluteString)
        let headers = try XCTUnwrap(server["headers"] as? [String: String])
        XCTAssertEqual(headers["Authorization"], "Bearer ${env:\(tokenKey)}")
        XCTAssertFalse(String(decoding: mcpData, as: UTF8.self).contains("runtime-secret"))
        XCTAssertFalse(prepared.commandArguments.contains { $0.contains("runtime-secret") })
    }

    @MainActor
    func testPrepareReplacesStaleRuntimeCredential() async throws {
        let settings = AppSettings()
        let tab = Tab(name: "Tab", directory: URL(filePath: "/tmp"))
        let pane = tab.addPane(name: "Pane", harness: .claude, appSettings: settings)
        pane.agentControlInjectionEnabled = true
        let service = AgentControlService.shared
        await service.start()
        defer {
            Task { await service.stop() }
        }

        let prepared = try AgentControlHarnessInjection.prepare(
            pane: pane,
            tab: tab,
            commandArguments: ["claude", "--mcp-config", "{\"agent-session-manager\":{}}"],
            environment: ["PATH=/usr/bin", "\(tokenKey)=stale-token"],
            appSettings: settings)

        XCTAssertEqual(
            prepared.1.filter { $0.hasPrefix("\(tokenKey)=") }.count,
            1)
        XCTAssertFalse(prepared.1.contains("\(tokenKey)=stale-token"))
        XCTAssertEqual(
            prepared.0?.filter { $0 == "--mcp-config" }.count,
            1)
    }

    func testRemovingControlTokenKeepsOtherEnvironmentValues() {
        let environment = [
            "PATH=/usr/bin",
            "\(tokenKey)=stale-token",
            "\(tokenKey)=duplicate-token",
            "HOME=/tmp",
        ]

        XCTAssertEqual(
            AgentControlHarnessInjection.removingControlToken(from: environment),
            ["PATH=/usr/bin", "HOME=/tmp"])
    }

    func testRemovingControlArgumentsRemovesOnlyAgentControlConfiguration() {
        let claudeArguments = [
            "claude", "--mcp-config", "{\"agent-session-manager\":{}}",
            "--mcp-config", "{\"other-server\":{}}",
        ]
        XCTAssertEqual(
            AgentControlHarnessInjection.removingControlArguments(
                from: claudeArguments, harness: .claude),
            ["claude", "--mcp-config", "{\"other-server\":{}}"])

        let codexArguments = [
            "codex", "-c", "mcp_servers.agent_session_manager.url=\"http://127.0.0.1\"",
            "-c", "model=\"gpt-5\"",
        ]
        XCTAssertEqual(
            AgentControlHarnessInjection.removingControlArguments(
                from: codexArguments, harness: .codex),
            ["codex", "-c", "model=\"gpt-5\""])

        let appOwnedPlugin = CursorAgentControlPlugin.directory(for: UUID()).path
        let cursorArguments = [
            "agent", "--plugin-dir", appOwnedPlugin,
            "--plugin-dir", "/Users/example/plugins/custom",
            "--model", "auto",
        ]
        XCTAssertEqual(
            AgentControlHarnessInjection.removingControlArguments(
                from: cursorArguments, harness: .cursor),
            ["agent", "--plugin-dir", "/Users/example/plugins/custom", "--model", "auto"])
    }
}
