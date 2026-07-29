import AgentSessionManagerMCPBridgeCore
import Darwin
import Foundation
import os

@main
struct AgentSessionManagerMCPBridge {
    private static let logger = Logger(
        subsystem: "com.justinfuller.agent-session-manager", category: "mcp-bridge")

    static func main() async {
        do {
            let configuration = try MCPBridgeConfiguration(
                environment: ProcessInfo.processInfo.environment)
            logger.info(
                "Bridge configuration accepted for \(configuration.endpoint.host ?? "?", privacy: .public):\(configuration.endpoint.port ?? 0, privacy: .public)"
            )
            let remoteTransport = AuthenticatedHTTPClientTransport(
                endpoint: configuration.endpoint,
                bearerToken: configuration.bearerToken)
            try await MCPTransportBridge(
                localTransport: BoundedStdioTransport(),
                remoteTransport: remoteTransport
            ).run()
            logger.info("Bridge exited cleanly.")
        } catch {
            let boundedDescription = String(error.localizedDescription.prefix(300))
            logger.error("Bridge run failed: \(boundedDescription, privacy: .public)")
            let message = "Agent Session Manager MCP bridge failed: " + boundedDescription + "\n"
            try? FileHandle.standardError.write(contentsOf: Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }
}
