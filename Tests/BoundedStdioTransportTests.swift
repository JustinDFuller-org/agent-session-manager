import Foundation
import MCP
import XCTest

@testable import AgentSessionManagerMCPBridgeCore

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

final class BoundedStdioTransportTests: XCTestCase {
    func testMessageSplitAcrossReadChunksArrivesAsOneFrame() async throws {
        let harness = try StdioTransportHarness()
        try await harness.transport.connect()

        try harness.writeToInput("first-half-")
        try await Task.sleep(for: .milliseconds(30))
        try harness.writeToInput("second-half\n")

        var messages = await harness.transport.receive().makeAsyncIterator()
        let message = try await messages.next()
        XCTAssertEqual(message.map { String(decoding: $0, as: UTF8.self) }, "first-half-second-half")

        await harness.transport.disconnect()
    }

    func testMultipleNewlineDelimitedMessagesInOneChunkArriveInOrder() async throws {
        let harness = try StdioTransportHarness()
        try await harness.transport.connect()

        try harness.writeToInput("one\ntwo\nthree\n")

        var messages = await harness.transport.receive().makeAsyncIterator()
        let received = try await [messages.next(), messages.next(), messages.next()]
            .map { $0.map { String(decoding: $0, as: UTF8.self) } }
        XCTAssertEqual(received, ["one", "two", "three"])

        await harness.transport.disconnect()
    }

    func testEmptyLinesAreSkippedNotYielded() async throws {
        let harness = try StdioTransportHarness()
        try await harness.transport.connect()

        try harness.writeToInput("\n\nmessage\n")

        var messages = await harness.transport.receive().makeAsyncIterator()
        let message = try await messages.next()
        XCTAssertEqual(message.map { String(decoding: $0, as: UTF8.self) }, "message")

        await harness.transport.disconnect()
    }

    func testReadFrameOverTheLimitSurfacesAnErrorOnTheReceiveStream() async throws {
        let harness = try StdioTransportHarness(maximumMessageBytes: 8)
        try await harness.transport.connect()

        try harness.writeToInput("0123456789012345\n")

        var messages = await harness.transport.receive().makeAsyncIterator()
        do {
            _ = try await messages.next()
            XCTFail("An oversized frame must surface an error rather than a message")
        } catch let error as MCPError {
            guard case .internalError = error else {
                XCTFail("Expected MCPError.internalError, got \(error)")
                return
            }
        }

        await harness.transport.disconnect()
    }

    func testSendRejectsOversizedMessagesBeforeWritingAnything() async throws {
        let harness = try StdioTransportHarness(maximumMessageBytes: 8)
        try await harness.transport.connect()

        do {
            try await harness.transport.send(Data(repeating: 0x61, count: 20))
            XCTFail("An oversized send must be rejected")
        } catch let error as MCPError {
            guard case .internalError = error else {
                XCTFail("Expected MCPError.internalError, got \(error)")
                return
            }
        }

        XCTAssertEqual(try harness.readAvailableFromOutput(), Data(), "No bytes may reach the peer for a rejected send")
        await harness.transport.disconnect()
    }

    func testSendAfterDisconnectThrowsConnectionClosed() async throws {
        let harness = try StdioTransportHarness()
        try await harness.transport.connect()
        await harness.transport.disconnect()

        do {
            try await harness.transport.send(Data("late".utf8))
            XCTFail("A send after disconnect must throw")
        } catch let error as MCPError {
            guard case .connectionClosed = error else {
                XCTFail("Expected MCPError.connectionClosed, got \(error)")
                return
            }
        }
    }

    func testCancellingASendBlockedOnABackedUpPipeUnwindsPromptly() async throws {
        let harness = try StdioTransportHarness()
        try await harness.transport.connect()
        try harness.fillOutputPipeUntilWouldBlock()

        let sendTask = Task {
            try await harness.transport.send(Data("blocked-message".utf8))
        }
        try await Task.sleep(for: .milliseconds(50))
        sendTask.cancel()

        let finishedInTime = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                _ = try? await sendTask.value
                return true
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(2))
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        XCTAssertTrue(
            finishedInTime,
            "Cancelling a send blocked on a full pipe must unwind promptly rather than hang the actor")

        await harness.transport.disconnect()
    }

    func testYieldingPastTheReceiveBufferSurfacesAnErrorRatherThanLosingAFrame() async throws {
        let harness = try StdioTransportHarness()
        try await harness.transport.connect()

        for index in 0..<80 {
            try harness.writeToInput("message-\(index)")
            try harness.writeRawToInput("\n")
        }
        try await Task.sleep(for: .milliseconds(100))

        var messages = await harness.transport.receive().makeAsyncIterator()
        var sawError = false
        do {
            while try await messages.next() != nil {}
        } catch {
            sawError = true
        }
        XCTAssertTrue(sawError, "Overflowing the receive buffer must surface an error, not silently drop frames")

        await harness.transport.disconnect()
    }
}

private final class StdioTransportHarness {
    let transport: BoundedStdioTransport
    private let inputWriteEnd: FileDescriptor
    private let outputReadEnd: FileDescriptor
    private let outputWriteEnd: FileDescriptor

    init(maximumMessageBytes: Int = MCPBridgeLimits.maximumMessageBytes) throws {
        let inputPipe = try FileDescriptor.pipe()
        let outputPipe = try FileDescriptor.pipe()
        inputWriteEnd = inputPipe.writeEnd
        outputReadEnd = outputPipe.readEnd
        outputWriteEnd = outputPipe.writeEnd
        try Self.setNonBlocking(outputReadEnd)
        transport = BoundedStdioTransport(
            input: inputPipe.readEnd, output: outputPipe.writeEnd, maximumMessageBytes: maximumMessageBytes)
    }

    func writeToInput(_ string: String) throws {
        try writeRawToInput(string)
    }

    func writeRawToInput(_ string: String) throws {
        var data = Data(string.utf8)
        try data.withUnsafeMutableBytes { buffer in
            _ = try inputWriteEnd.write(UnsafeRawBufferPointer(buffer))
        }
    }

    func fillOutputPipeUntilWouldBlock() throws {
        let chunk = [UInt8](repeating: 0x61, count: 65536)
        while true {
            do {
                _ = try chunk.withUnsafeBytes { try outputWriteEnd.write(UnsafeRawBufferPointer($0)) }
            } catch let error as Errno where error == .resourceTemporarilyUnavailable {
                return
            }
        }
    }

    func readAvailableFromOutput() throws -> Data {
        var buffer = [UInt8](repeating: 0, count: 4096)
        do {
            let bytesRead = try buffer.withUnsafeMutableBufferPointer { pointer in
                try outputReadEnd.read(into: UnsafeMutableRawBufferPointer(pointer))
            }
            return Data(buffer[..<bytesRead])
        } catch let error as Errno where error == .resourceTemporarilyUnavailable {
            return Data()
        }
    }

    private static func setNonBlocking(_ fileDescriptor: FileDescriptor) throws {
        let flags = fcntl(fileDescriptor.rawValue, F_GETFL)
        guard flags >= 0 else {
            throw MCPError.transportError(Errno(rawValue: CInt(errno)))
        }
        guard fcntl(fileDescriptor.rawValue, F_SETFL, flags | O_NONBLOCK) >= 0 else {
            throw MCPError.transportError(Errno(rawValue: CInt(errno)))
        }
    }
}
