import Darwin
import Foundation
import XCTest

@testable import AgentSessionManager

final class ChildProcessInputWriterTests: XCTestCase {
    func testClosedReadEndDoesNotSIGPIPEProcessWithDefaultDisposition() throws {
        let childEnvironmentKey = "AGENT_SESSION_MANAGER_SIGPIPE_TEST_CHILD"
        if ProcessInfo.processInfo.environment[childEnvironmentKey] == "1" {
            signal(SIGPIPE, SIG_DFL)
            let pipe = Pipe()
            try pipe.fileHandleForReading.close()
            let failure = ChildProcessInputWriter.write(
                Data("payload".utf8),
                to: pipe.fileHandleForWriting,
                timeout: 1)
            XCTAssertEqual(failure?.stage, .write)
            XCTAssertEqual(failure?.errorCode, EPIPE)
            return
        }

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcrun")
        process.arguments = [
            "xctest",
            "-XCTest",
            "AgentSessionManagerTests.ChildProcessInputWriterTests/"
                + "testClosedReadEndDoesNotSIGPIPEProcessWithDefaultDisposition",
            Bundle(for: type(of: self)).bundlePath,
        ]
        var environment = ProcessInfo.processInfo.environment
        environment[childEnvironmentKey] = "1"
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationReason, .exit)
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testLargePayloadIsFullyWrittenWhileChildReads() async {
        let pipe = Pipe()
        let payload = Data(repeating: 0x61, count: 1_000_000)
        let reader = Task.detached {
            pipe.fileHandleForReading.readDataToEndOfFile()
        }

        let failure = ChildProcessInputWriter.write(
            payload,
            to: pipe.fileHandleForWriting,
            timeout: 2)
        let received = await reader.value

        XCTAssertNil(failure)
        XCTAssertEqual(received, payload)
    }
}
