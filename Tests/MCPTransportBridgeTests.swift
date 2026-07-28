import AgentSessionManagerMCPBridgeCore
import Foundation
import MCP
import XCTest

final class MCPTransportBridgeTests: XCTestCase {
    func testConfigurationAcceptsOnlyLoopbackMCPURLAndRuntimeToken() throws {
        let configuration = try MCPBridgeConfiguration(environment: [
            MCPBridgeEnvironment.endpointKey: "http://127.0.0.1:43123/mcp",
            MCPBridgeEnvironment.tokenKey: "runtime-secret",
        ])

        XCTAssertEqual(configuration.endpoint.absoluteString, "http://127.0.0.1:43123/mcp")
        XCTAssertEqual(configuration.bearerToken, "runtime-secret")
    }

    func testConfigurationRejectsMissingAndUnsafeValues() {
        XCTAssertThrowsError(try MCPBridgeConfiguration(environment: [:])) { error in
            XCTAssertEqual(error as? MCPBridgeConfigurationError, .missingEndpoint)
        }
        XCTAssertThrowsError(
            try MCPBridgeConfiguration(environment: [
                MCPBridgeEnvironment.endpointKey: "https://example.com/mcp",
                MCPBridgeEnvironment.tokenKey: "secret",
            ])
        ) { error in
            XCTAssertEqual(error as? MCPBridgeConfigurationError, .invalidEndpoint)
        }
        XCTAssertThrowsError(
            try MCPBridgeConfiguration(environment: [
                MCPBridgeEnvironment.endpointKey: "http://127.0.0.1:43123/mcp?token=secret",
                MCPBridgeEnvironment.tokenKey: "secret",
            ])
        ) { error in
            XCTAssertEqual(error as? MCPBridgeConfigurationError, .invalidEndpoint)
        }
        XCTAssertThrowsError(
            try MCPBridgeConfiguration(environment: [
                MCPBridgeEnvironment.endpointKey: "http://127.0.0.1:43123/mcp"
            ])
        ) { error in
            XCTAssertEqual(error as? MCPBridgeConfigurationError, .missingToken)
        }
        XCTAssertThrowsError(
            try MCPBridgeConfiguration(environment: [
                MCPBridgeEnvironment.endpointKey: "http://127.0.0.1:43123/mcp",
                MCPBridgeEnvironment.tokenKey: "invalid token",
            ])
        ) { error in
            XCTAssertEqual(error as? MCPBridgeConfigurationError, .invalidToken)
        }
    }

    func testBridgeForwardsMessagesInBothDirections() async throws {
        let localPair = await InMemoryTransport.createConnectedPair()
        let remotePair = await InMemoryTransport.createConnectedPair()
        try await localPair.client.connect()
        try await remotePair.server.connect()

        let bridgeTask = Task {
            try await MCPTransportBridge(
                localTransport: localPair.server,
                remoteTransport: remotePair.client
            ).run()
        }
        try await Task.sleep(for: .milliseconds(20))

        let request = Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#.utf8)
        try await localPair.client.send(request)
        var remoteMessages = await remotePair.server.receive().makeAsyncIterator()
        let receivedRequest = try await remoteMessages.next()
        XCTAssertEqual(receivedRequest, request)

        let response = Data(#"{"jsonrpc":"2.0","id":1,"result":{}}"#.utf8)
        try await remotePair.server.send(response)
        var localMessages = await localPair.client.receive().makeAsyncIterator()
        let receivedResponse = try await localMessages.next()
        XCTAssertEqual(receivedResponse, response)

        await localPair.client.disconnect()
        _ = try? await bridgeTask.value
        await remotePair.server.disconnect()
    }

    func testBridgeForwardsCancellationWhileRequestIsRunning() async throws {
        let localPair = await InMemoryTransport.createConnectedPair()
        let remoteTransport = SlowRequestTransport()
        try await localPair.client.connect()
        let bridgeTask = Task {
            try await MCPTransportBridge(
                localTransport: localPair.server,
                remoteTransport: remoteTransport
            ).run()
        }
        try await Task.sleep(for: .milliseconds(20))

        for requestID in 1...4 {
            try await localPair.client.send(
                Data(
                    #"{"jsonrpc":"2.0","id":\#(requestID),"method":"tools/call","params":{"slow":true}}"#
                        .utf8))
        }
        try await localPair.client.send(
            Data(#"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":1}}"#.utf8))
        try await Task.sleep(for: .milliseconds(75))

        let receivedCancellation = await remoteTransport.receivedCancellation
        XCTAssertTrue(
            receivedCancellation,
            "Cancellation must not wait for the in-flight HTTP request to complete")

        await localPair.client.disconnect()
        _ = try? await bridgeTask.value
    }

    func testBridgeRejectsOversizedMessages() async throws {
        let localPair = await InMemoryTransport.createConnectedPair()
        let remotePair = await InMemoryTransport.createConnectedPair()
        try await localPair.client.connect()
        try await remotePair.server.connect()
        let bridgeTask = Task {
            try await MCPTransportBridge(
                localTransport: localPair.server,
                remoteTransport: remotePair.client
            ).run()
        }
        try await Task.sleep(for: .milliseconds(20))

        try await localPair.client.send(Data(repeating: 0x61, count: 1_048_577))
        do {
            try await bridgeTask.value
            XCTFail("The bridge must reject messages above its one MiB limit")
        } catch {
            XCTAssertNotNil(error)
        }
        await localPair.client.disconnect()
        await remotePair.server.disconnect()
    }
}

private actor SlowRequestTransport: Transport {
    nonisolated let logger = InMemoryTransport().logger
    private let stream: AsyncThrowingStream<Data, Swift.Error>
    private let continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation
    private(set) var receivedCancellation = false

    init() {
        var continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation!
        stream = AsyncThrowingStream { continuation = $0 }
        self.continuation = continuation
    }

    func connect() async throws {}

    func disconnect() async {
        continuation.finish()
    }

    func send(_ data: Data) async throws {
        let text = String(decoding: data, as: UTF8.self)
        if text.contains("notifications/cancelled") {
            receivedCancellation = true
        } else {
            try await Task.sleep(for: .milliseconds(500))
        }
    }

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        stream
    }
}
