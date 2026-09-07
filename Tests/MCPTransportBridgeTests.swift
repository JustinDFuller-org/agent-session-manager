import Foundation
import MCP
import XCTest

@testable import AgentSessionManagerMCPBridgeCore

final class MCPTransportBridgeTests: XCTestCase {
    func testConfigurationAcceptsOnlyLoopbackMCPURLAndRuntimeToken() throws {
        let configuration = try MCPBridgeConfiguration(environment: [
            MCPBridgeEnvironment.endpointKey: "http://127.0.0.1:43123/mcp",
            MCPBridgeEnvironment.tokenKey: "runtime-secret",
        ])

        XCTAssertEqual(configuration.endpoint.absoluteString, "http://127.0.0.1:43123/mcp")
        XCTAssertEqual(configuration.bearerToken, "runtime-secret")
    }

    func testMakeLoopbackEndpointRoundTripsThroughConfigurationForAnyValidPort() throws {
        for port in [1, 80, 43123, 65_535] {
            let endpoint = try XCTUnwrap(MCPBridgeEnvironment.makeLoopbackEndpoint(port: port))
            let configuration = try MCPBridgeConfiguration(environment: [
                MCPBridgeEnvironment.endpointKey: endpoint.absoluteString,
                MCPBridgeEnvironment.tokenKey: "runtime-secret",
            ])
            XCTAssertEqual(configuration.endpoint, endpoint)
        }
    }

    func testMakeLoopbackEndpointRejectsPortsOutsideTheValidRange() {
        XCTAssertNil(MCPBridgeEnvironment.makeLoopbackEndpoint(port: 0))
        XCTAssertNil(MCPBridgeEnvironment.makeLoopbackEndpoint(port: 65_536))
        XCTAssertNil(MCPBridgeEnvironment.makeLoopbackEndpoint(port: -1))
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

        let readyGate = ReadyGate()
        let bridgeTask = Task {
            try await MCPTransportBridge(
                localTransport: ReadySignalingTransport(wrapping: localPair.server, gate: readyGate),
                remoteTransport: remotePair.client
            ).run()
        }
        await readyGate.wait()

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
        let readyGate = ReadyGate()
        let bridgeTask = Task {
            try await MCPTransportBridge(
                localTransport: ReadySignalingTransport(wrapping: localPair.server, gate: readyGate),
                remoteTransport: remoteTransport
            ).run()
        }
        await readyGate.wait()

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
        let readyGate = ReadyGate()
        let bridgeTask = Task {
            try await MCPTransportBridge(
                localTransport: ReadySignalingTransport(wrapping: localPair.server, gate: readyGate),
                remoteTransport: remotePair.client
            ).run()
        }
        await readyGate.wait()

        try await localPair.client.send(Data(repeating: 0x61, count: 1_048_577))
        do {
            try await bridgeTask.value
            XCTFail("The bridge must reject messages above its one MiB limit")
        } catch let error as MCPError {
            guard case .internalError = error else {
                XCTFail("Expected MCPError.internalError, got \(error)")
                return
            }
        } catch {
            XCTFail("Expected MCPError, got \(error)")
        }
        await localPair.client.disconnect()
        await remotePair.server.disconnect()
    }

    func testBridgePreservesNotificationOrderingAcrossTheHandshake() async throws {
        let localPair = await InMemoryTransport.createConnectedPair()
        let remoteTransport = OrderRecordingTransport()
        try await localPair.client.connect()
        let readyGate = ReadyGate()
        let bridgeTask = Task {
            try await MCPTransportBridge(
                localTransport: ReadySignalingTransport(wrapping: localPair.server, gate: readyGate),
                remoteTransport: remoteTransport
            ).run()
        }
        await readyGate.wait()

        try await localPair.client.send(
            Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#.utf8))
        try await localPair.client.send(
            Data(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.utf8))
        try await localPair.client.send(
            Data(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#.utf8))
        try await Task.sleep(for: .milliseconds(200))

        let observedMethods = await remoteTransport.observedMethods
        XCTAssertEqual(
            observedMethods, ["initialize", "notifications/initialized", "tools/list"],
            "notifications/initialized must reach the peer before the request that follows it")

        await localPair.client.disconnect()
        _ = try? await bridgeTask.value
    }

    func testBridgeAllowsConcurrentRequestsToOverlap() async throws {
        let localPair = await InMemoryTransport.createConnectedPair()
        let remoteTransport = ConcurrencyTrackingTransport()
        try await localPair.client.connect()
        let readyGate = ReadyGate()
        let bridgeTask = Task {
            try await MCPTransportBridge(
                localTransport: ReadySignalingTransport(wrapping: localPair.server, gate: readyGate),
                remoteTransport: remoteTransport
            ).run()
        }
        await readyGate.wait()

        for requestID in 1...3 {
            try await localPair.client.send(
                Data(#"{"jsonrpc":"2.0","id":\#(requestID),"method":"tools/call","params":{"slow":true}}"#.utf8))
        }
        try await Task.sleep(for: .milliseconds(200))

        let observedMaxConcurrency = await remoteTransport.maxConcurrency
        XCTAssertEqual(
            observedMaxConcurrency, 3,
            "Three concurrent requests must overlap rather than run one after another")

        await localPair.client.disconnect()
        _ = try? await bridgeTask.value
    }

    func testBridgeAdmitsMoreBytesThanTheBudgetWithoutLoss() async throws {
        let localPair = await InMemoryTransport.createConnectedPair()
        let remotePair = await InMemoryTransport.createConnectedPair()
        try await localPair.client.connect()
        try await remotePair.server.connect()
        let readyGate = ReadyGate()
        let bridgeTask = Task {
            try await MCPTransportBridge(
                localTransport: ReadySignalingTransport(wrapping: localPair.server, gate: readyGate),
                remoteTransport: remotePair.client
            ).run()
        }
        await readyGate.wait()

        let payloadSize = 400_000
        let requestCount = (MCPBridgeLimits.pendingSendBytes / payloadSize) + 4
        let padding = String(repeating: "a", count: payloadSize)
        for requestID in 1...requestCount {
            try await localPair.client.send(
                Data(
                    #"{"jsonrpc":"2.0","id":\#(requestID),"method":"tools/call","params":{"pad":"\#(padding)"}}"#
                        .utf8))
        }

        var remoteMessages = await remotePair.server.receive().makeAsyncIterator()
        var receivedIDs = Set<Int>()
        for _ in 1...requestCount {
            let message = try await remoteMessages.next()
            let object = try JSONSerialization.jsonObject(with: message!) as? [String: Any]
            receivedIDs.insert(object?["id"] as? Int ?? -1)
        }
        XCTAssertEqual(
            receivedIDs, Set(1...requestCount),
            "Every request must be forwarded despite exceeding the pending-byte budget")

        await localPair.client.disconnect()
        _ = try? await bridgeTask.value
        await remotePair.server.disconnect()
    }
}

final class BridgeSendLimiterTests: XCTestCase {
    func testLimiterAdmitsUpToCapacityThenBlocksThenAdmitsAfterRelease() async throws {
        let limiter = BridgeSendLimiter(capacity: 2)
        try await limiter.acquire()
        try await limiter.acquire()

        let admitted = TestFlag()
        let waiter = Task {
            try await limiter.acquire()
            await admitted.set(true)
        }

        try await Task.sleep(for: .milliseconds(50))
        let stillBlocked = await admitted.value
        XCTAssertFalse(stillBlocked, "an acquire beyond capacity must block")

        await limiter.release()
        try await Task.sleep(for: .milliseconds(50))
        let admittedAfterRelease = await admitted.value
        XCTAssertTrue(admittedAfterRelease, "the blocked acquire must be admitted once capacity is released")
        _ = try await waiter.value
    }

    func testLimiterWaitsForACostLargerThanRemainingCapacity() async throws {
        let limiter = BridgeSendLimiter(capacity: 10)
        try await limiter.acquire(4)

        let admitted = TestFlag()
        let waiter = Task {
            try await limiter.acquire(8)
            await admitted.set(true)
        }

        try await Task.sleep(for: .milliseconds(50))
        let stillWaiting = await admitted.value
        XCTAssertFalse(stillWaiting, "a cost larger than the remaining capacity must wait")

        await limiter.release(4)
        try await Task.sleep(for: .milliseconds(50))
        let admittedAfterEnoughCapacity = await admitted.value
        XCTAssertTrue(admittedAfterEnoughCapacity, "the waiter must be admitted once enough capacity is released")
        _ = try await waiter.value
    }

    func testCancelledWaiterResumesAndDoesNotStrandCapacity() async throws {
        let limiter = BridgeSendLimiter(capacity: 1)
        try await limiter.acquire()

        let waiter = Task {
            try await limiter.acquire()
        }
        try await Task.sleep(for: .milliseconds(30))
        waiter.cancel()

        do {
            _ = try await waiter.value
            XCTFail("A cancelled waiter must resume with an error rather than hang")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        await limiter.release()
        try await limiter.acquire()
    }
}

private actor ReadyGate {
    private var isReady = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func markReady() {
        guard !isReady else { return }
        isReady = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }

    func wait() async {
        if isReady { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

private actor ReadySignalingTransport: Transport {
    nonisolated let logger = InMemoryTransport().logger
    private let wrapped: any Transport
    private let gate: ReadyGate
    private var cachedStream: AsyncThrowingStream<Data, Swift.Error>?

    init(wrapping wrapped: any Transport, gate: ReadyGate) {
        self.wrapped = wrapped
        self.gate = gate
    }

    func connect() async throws {
        try await wrapped.connect()
        cachedStream = await wrapped.receive()
        await gate.markReady()
    }

    func disconnect() async {
        await wrapped.disconnect()
    }

    func send(_ data: Data) async throws {
        try await wrapped.send(data)
    }

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        cachedStream ?? AsyncThrowingStream { $0.finish() }
    }
}

private actor TestFlag {
    private(set) var value = false

    func set(_ newValue: Bool) {
        value = newValue
    }
}

private actor ConcurrencyTrackingTransport: Transport {
    nonisolated let logger = InMemoryTransport().logger
    private let stream: AsyncThrowingStream<Data, Swift.Error>
    private let continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation
    private var currentConcurrency = 0
    private(set) var maxConcurrency = 0

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
        currentConcurrency += 1
        maxConcurrency = max(maxConcurrency, currentConcurrency)
        try await Task.sleep(for: .milliseconds(100))
        currentConcurrency -= 1
    }

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        stream
    }
}

private actor OrderRecordingTransport: Transport {
    nonisolated let logger = InMemoryTransport().logger
    private let stream: AsyncThrowingStream<Data, Swift.Error>
    private let continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation
    private(set) var observedMethods: [String] = []

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
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let method = object?["method"] as? String ?? ""
        if method == "initialize" {
            try await Task.sleep(for: .milliseconds(50))
        }
        observedMethods.append(method)
    }

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        stream
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
