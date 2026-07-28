import Foundation
import MCP

public enum MCPBridgeEnvironment {
    public static let endpointKey = "AGENT_SESSION_MANAGER_MCP_ENDPOINT"
    public static let tokenKey = "AGENT_SESSION_MANAGER_MCP_TOKEN"
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
            components.scheme == "http",
            components.host == "127.0.0.1",
            let port = components.port,
            (1...65_535).contains(port),
            components.path == "/mcp",
            components.user == nil,
            components.password == nil,
            components.query == nil,
            components.fragment == nil,
            let endpoint = components.url
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

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Self.forward(from: localTransport, to: remoteTransport)
                }
                group.addTask {
                    try await Self.forward(from: remoteTransport, to: localTransport)
                }

                _ = try await group.next()
                group.cancelAll()
            }
        } catch {
            await localTransport.disconnect()
            await remoteTransport.disconnect()
            throw error
        }

        await localTransport.disconnect()
        await remoteTransport.disconnect()
    }

    private static func forward(from source: any Transport, to destination: any Transport) async throws {
        let messages = await source.receive()
        let normalLimiter = BridgeSendLimiter(limit: 3)
        let priorityLimiter = BridgeSendLimiter(limit: 1)
        try await withThrowingTaskGroup(of: Void.self) { sends in
            var inFlight = 0

            for try await message in messages {
                try Task.checkCancellation()
                guard message.count <= 1_048_576 else {
                    throw MCPError.internalError("MCP message exceeds the allowed size.")
                }

                let object = try? JSONSerialization.jsonObject(with: message)
                let methods: [String?]
                if let request = object as? [String: Any] {
                    methods = [request["method"] as? String]
                } else if let batch = object as? [[String: Any]] {
                    methods = batch.map { $0["method"] as? String }
                } else {
                    methods = []
                }
                let isPriority = methods.contains {
                    $0 == nil || $0 == "notifications/cancelled"
                }
                if inFlight >= 64 {
                    _ = try await sends.next()
                    inFlight -= 1
                }

                sends.addTask {
                    if isPriority {
                        await priorityLimiter.wait()
                    } else {
                        await normalLimiter.wait()
                    }
                    do {
                        try Task.checkCancellation()
                        try await destination.send(message)
                    } catch {
                        if isPriority {
                            await priorityLimiter.signal()
                        } else {
                            await normalLimiter.signal()
                        }
                        throw error
                    }
                    if isPriority {
                        await priorityLimiter.signal()
                    } else {
                        await normalLimiter.signal()
                    }
                }
                inFlight += 1
            }

            try await sends.waitForAll()
        }
    }
}

private actor BridgeSendLimiter {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        available = limit
    }

    func wait() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if waiters.isEmpty {
            available += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}
