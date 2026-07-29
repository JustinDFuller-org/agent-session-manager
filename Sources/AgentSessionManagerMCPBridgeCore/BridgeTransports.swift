import Foundation
import Logging
import MCP

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

#if canImport(Darwin)
import Darwin.POSIX
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

public actor AuthenticatedHTTPClientTransport: Transport {
    public nonisolated let logger: Logger

    private let endpoint: URL
    private let bearerToken: String
    private let transport: HTTPClientTransport
    private let cleanupSession: URLSession
    private var messageStream: AsyncThrowingStream<Data, Swift.Error>?

    public init(endpoint: URL, bearerToken: String) {
        self.endpoint = endpoint
        self.bearerToken = bearerToken
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = [
            "Authorization": "Bearer \(bearerToken)"
        ]
        transport = HTTPClientTransport(endpoint: endpoint, configuration: configuration)
        let cleanupConfiguration = URLSessionConfiguration.ephemeral
        cleanupConfiguration.timeoutIntervalForRequest = 2
        cleanupSession = URLSession(configuration: cleanupConfiguration)
        logger = transport.logger
    }

    public func connect() async throws {
        try await transport.connect()
        messageStream = await transport.receive()
    }

    public func disconnect() async {
        if let sessionID = await transport.sessionID {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "DELETE"
            request.timeoutInterval = 2
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
            request.setValue(sessionID, forHTTPHeaderField: "MCP-Session-Id")
            _ = try? await cleanupSession.data(for: request)
        }
        cleanupSession.invalidateAndCancel()
        await transport.disconnect()
    }

    public func send(_ data: Data) async throws {
        try await transport.send(data)
    }

    public func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        guard let messageStream else {
            return AsyncThrowingStream { $0.finish(throwing: MCPError.connectionClosed) }
        }
        return messageStream
    }
}

public actor BoundedStdioTransport: Transport {
    public nonisolated let logger: Logger

    private let input: FileDescriptor
    private let output: FileDescriptor
    private let maximumMessageBytes: Int
    private var isConnected = false
    private let messageStream: AsyncThrowingStream<Data, Swift.Error>
    private let messageContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation

    public init(
        input: FileDescriptor = .standardInput,
        output: FileDescriptor = .standardOutput,
        maximumMessageBytes: Int = MCPBridgeLimits.maximumMessageBytes
    ) {
        self.input = input
        self.output = output
        self.maximumMessageBytes = maximumMessageBytes
        logger = Logger(
            label: "agent-session-manager.mcp-bridge.stdio",
            factory: { _ in SwiftLogNoOpLogHandler() })
        var continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation!
        messageStream = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(64)) {
            continuation = $0
        }
        messageContinuation = continuation
    }

    public func connect() async throws {
        guard !isConnected else { return }
        try setNonBlocking(fileDescriptor: input)
        try setNonBlocking(fileDescriptor: output)
        isConnected = true

        Task {
            let bufferSize = 4096
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            var pendingData = Data()

            while isConnected && !Task.isCancelled {
                do {
                    let bytesRead = try buffer.withUnsafeMutableBufferPointer { pointer in
                        try input.read(into: UnsafeMutableRawBufferPointer(pointer))
                    }
                    if bytesRead == 0 { break }
                    pendingData.append(Data(buffer[..<bytesRead]))
                    guard pendingData.count <= maximumMessageBytes else {
                        messageContinuation.finish(
                            throwing: MCPError.internalError(
                                "Stdio MCP message exceeds the allowed size."))
                        isConnected = false
                        return
                    }
                    while let newlineIndex = pendingData.firstIndex(of: UInt8(ascii: "\n")) {
                        let message = Data(pendingData[..<newlineIndex])
                        pendingData = pendingData[(newlineIndex + 1)...]
                        if !message.isEmpty {
                            switch messageContinuation.yield(message) {
                            case .enqueued:
                                break
                            case .dropped:
                                messageContinuation.finish(
                                    throwing: MCPError.internalError(
                                        "Stdio MCP message queue exceeds the allowed size."))
                                isConnected = false
                                return
                            case .terminated:
                                isConnected = false
                                return
                            @unknown default:
                                isConnected = false
                                return
                            }
                        }
                    }
                } catch let error where MCPError.isResourceTemporarilyUnavailable(error) {
                    try? await Task.sleep(for: .milliseconds(10))
                } catch {
                    messageContinuation.finish(throwing: error)
                    isConnected = false
                    return
                }
            }
            messageContinuation.finish()
            isConnected = false
        }
    }

    public func disconnect() async {
        guard isConnected else { return }
        isConnected = false
        messageContinuation.finish()
    }

    public func send(_ data: Data) async throws {
        guard isConnected else {
            throw MCPError.connectionClosed
        }
        guard data.count <= maximumMessageBytes else {
            throw MCPError.internalError("Stdio MCP message exceeds the allowed size.")
        }

        var remaining = data
        remaining.append(UInt8(ascii: "\n"))
        while !remaining.isEmpty {
            try Task.checkCancellation()
            let written: Int
            do {
                written = try remaining.withUnsafeBytes { buffer in
                    try output.write(UnsafeRawBufferPointer(buffer))
                }
            } catch let error where MCPError.isResourceTemporarilyUnavailable(error) {
                try await Task.sleep(for: .milliseconds(10))
                continue
            } catch {
                throw MCPError.transportError(error)
            }
            guard written > 0 else {
                throw MCPError.transportError(Errno(rawValue: CInt(EIO)))
            }
            remaining = remaining.dropFirst(written)
        }
    }

    public func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        messageStream
    }

    private func setNonBlocking(fileDescriptor: FileDescriptor) throws {
        let flags = fcntl(fileDescriptor.rawValue, F_GETFL)
        guard flags >= 0 else {
            throw MCPError.transportError(Errno(rawValue: CInt(errno)))
        }
        guard fcntl(fileDescriptor.rawValue, F_SETFL, flags | O_NONBLOCK) >= 0 else {
            throw MCPError.transportError(Errno(rawValue: CInt(errno)))
        }
    }
}
