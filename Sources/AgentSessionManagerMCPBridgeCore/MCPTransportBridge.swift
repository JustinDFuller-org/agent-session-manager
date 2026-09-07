import Foundation
import MCP

public enum MCPBridgeLimits {
    public static let maximumMessageBytes = 1_048_576
    public static let pendingSendBytes = 8 * maximumMessageBytes
}

public enum MCPBridgeEnvironment {
    public static let endpointKey = "AGENT_SESSION_MANAGER_MCP_ENDPOINT"
    public static let tokenKey = "AGENT_SESSION_MANAGER_MCP_TOKEN"
    public static let bundledExecutableRelativePath = "Contents/Helpers/AgentSessionManagerMCPBridge"

    public static func makeLoopbackEndpoint(port: Int) -> URL? {
        guard (1...65_535).contains(port) else { return nil }
        return URL(string: "http://127.0.0.1:\(port)/mcp")
    }
}

public enum MCPBridgeConfigurationError: LocalizedError, Equatable {
    case missingEndpoint
    case invalidEndpoint
    case missingToken
    case invalidToken

    public var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "The Agent Control endpoint is missing."
        case .invalidEndpoint:
            return "The Agent Control endpoint is invalid."
        case .missingToken:
            return "The Agent Control credential is missing."
        case .invalidToken:
            return "The Agent Control credential is invalid."
        }
    }
}

public struct MCPBridgeConfiguration: Sendable {
    public let endpoint: URL
    public let bearerToken: String

    public init(environment: [String: String]) throws {
        guard let endpointValue = environment[MCPBridgeEnvironment.endpointKey],
            !endpointValue.isEmpty
        else {
            throw MCPBridgeConfigurationError.missingEndpoint
        }
        guard let components = URLComponents(string: endpointValue),
            let port = components.port,
            let endpoint = MCPBridgeEnvironment.makeLoopbackEndpoint(port: port),
            endpoint.absoluteString == endpointValue
        else {
            throw MCPBridgeConfigurationError.invalidEndpoint
        }
        guard let bearerToken = environment[MCPBridgeEnvironment.tokenKey],
            !bearerToken.isEmpty
        else {
            throw MCPBridgeConfigurationError.missingToken
        }
        guard
            bearerToken.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else {
            throw MCPBridgeConfigurationError.invalidToken
        }

        self.endpoint = endpoint
        self.bearerToken = bearerToken
    }
}

public struct MCPTransportBridge: Sendable {
    private let localTransport: any Transport
    private let remoteTransport: any Transport

    public init(localTransport: any Transport, remoteTransport: any Transport) {
        self.localTransport = localTransport
        self.remoteTransport = remoteTransport
    }

    public func run() async throws {
        try await localTransport.connect()
        do {
            try await remoteTransport.connect()
        } catch {
            await localTransport.disconnect()
            throw error
        }

        let forwardingResult = await withThrowingTaskGroup(of: Void.self) { group -> Result<Void, Error> in
            group.addTask {
                try await Self.forward(from: localTransport, to: remoteTransport)
            }
            group.addTask {
                try await Self.forward(from: remoteTransport, to: localTransport)
            }

            let firstOutcome: Result<Void, Error>
            do {
                _ = try await group.next()
                firstOutcome = .success(())
            } catch {
                firstOutcome = .failure(error)
            }
            group.cancelAll()
            _ = try? await group.next()
            return firstOutcome
        }

        await localTransport.disconnect()
        await remoteTransport.disconnect()

        if case .failure(let error) = forwardingResult {
            throw error
        }
    }

    private static func forward(from source: any Transport, to destination: any Transport) async throws {
        let messages = await source.receive()
        let concurrentLimiter = BridgeSendLimiter(capacity: 3)
        let bypassLimiter = BridgeSendLimiter(capacity: 1)
        let pendingBytes = BridgeSendLimiter(capacity: MCPBridgeLimits.pendingSendBytes)

        try await withThrowingTaskGroup(of: Void.self) { sends in
            var inFlight = 0

            for try await message in messages {
                try Task.checkCancellation()
                guard message.count <= MCPBridgeLimits.maximumMessageBytes else {
                    throw MCPError.internalError("MCP message exceeds the allowed size.")
                }

                switch BridgeFrame.classify(message) {
                case .ordered:
                    while inFlight > 0 {
                        _ = try await sends.next()
                        inFlight -= 1
                    }
                    try await destination.send(message)

                case .bypass:
                    try await pendingBytes.acquire(message.count)
                    sends.addTask {
                        try await Self.send(
                            message, to: destination, limiter: bypassLimiter, pendingBytes: pendingBytes)
                    }
                    inFlight += 1

                case .concurrent:
                    try await pendingBytes.acquire(message.count)
                    sends.addTask {
                        try await Self.send(
                            message, to: destination, limiter: concurrentLimiter, pendingBytes: pendingBytes)
                    }
                    inFlight += 1
                }
            }

            try await sends.waitForAll()
        }
    }

    private static func send(
        _ message: Data, to destination: any Transport, limiter: BridgeSendLimiter,
        pendingBytes: BridgeSendLimiter
    ) async throws {
        try await limiter.acquire()
        do {
            try Task.checkCancellation()
            try await destination.send(message)
        } catch {
            await limiter.release()
            await pendingBytes.release(message.count)
            throw error
        }
        await limiter.release()
        await pendingBytes.release(message.count)
    }
}

enum BridgeFrame {
    enum Kind {
        case bypass
        case ordered
        case concurrent
    }

    static func classify(_ message: Data) -> Kind {
        guard let object = try? JSONSerialization.jsonObject(with: message) else {
            return .ordered
        }
        let entries: [[String: Any]]
        switch object {
        case let single as [String: Any]:
            entries = [single]
        case let batch as [[String: Any]]:
            entries = batch
        default:
            return .ordered
        }
        guard !entries.isEmpty else { return .ordered }

        if entries.contains(where: { $0["method"] as? String == "notifications/cancelled" || $0["method"] == nil }) {
            return .bypass
        }
        if entries.contains(where: { $0["id"] == nil }) {
            return .ordered
        }
        return .concurrent
    }
}

actor BridgeSendLimiter {
    private struct Waiter {
        let cost: Int
        let continuation: CheckedContinuation<Void, Error>
    }

    private let capacity: Int
    private var available: Int
    private var nextWaiterID = 0
    private var waiterOrder: [Int] = []
    private var waiters: [Int: Waiter] = [:]

    init(capacity: Int) {
        self.capacity = capacity
        available = capacity
    }

    func acquire(_ cost: Int = 1) async throws {
        try Task.checkCancellation()
        if waiterOrder.isEmpty, cost <= available {
            available -= cost
            return
        }
        let id = nextWaiterID
        nextWaiterID += 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                waiterOrder.append(id)
                waiters[id] = Waiter(cost: cost, continuation: continuation)
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    func release(_ cost: Int = 1) {
        available += cost
        admitWaiters()
    }

    private func admitWaiters() {
        while let id = waiterOrder.first, let waiter = waiters[id], waiter.cost <= available {
            available -= waiter.cost
            waiterOrder.removeFirst()
            waiters.removeValue(forKey: id)
            waiter.continuation.resume()
        }
    }

    private func cancelWaiter(_ id: Int) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        waiterOrder.removeAll { $0 == id }
        waiter.continuation.resume(throwing: CancellationError())
    }
}
