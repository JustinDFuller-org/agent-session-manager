import AgentSessionManagerMCPBridgeCore
import Darwin
import Foundation

@main
struct AgentSessionManagerMCPBridge {
    static func main() async {
        do {
            let configuration = try MCPBridgeConfiguration(
                environment: ProcessInfo.processInfo.environment)
            let remoteTransport = AuthenticatedHTTPClientTransport(
                endpoint: configuration.endpoint,
                bearerToken: configuration.bearerToken)
            try await MCPTransportBridge(
                localTransport: BoundedStdioTransport(),
                remoteTransport: remoteTransport
            ).run()
        } catch {
            let message =
                "Agent Session Manager MCP bridge failed: "
                + String(error.localizedDescription.prefix(300))
                + "\n"
            try? FileHandle.standardError.write(contentsOf: Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }
}
