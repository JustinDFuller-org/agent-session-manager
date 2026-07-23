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
        let existing = "{\"share\":\"manual\",\"permission\":{\"*\":\"ask\"}}"
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
        XCTAssertEqual(config["share"] as? String, "manual")
    }

    func testCursorReportsActionableUnsupportedError() {
        let context = AgentControlHarnessLaunchContext(
            endpoint: endpoint, tokenEnvironmentKey: tokenKey, commandArguments: ["agent"], environment: []
        )

        XCTAssertThrowsError(try CursorAgentControlAdapter().prepare(context)) { error in
            XCTAssertEqual(error as? AgentControlHarnessInjectionError, .unsupported(.cursor))
            XCTAssertTrue(error.localizedDescription.contains("Cursor"))
        }
    }
}
