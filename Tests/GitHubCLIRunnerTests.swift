import Darwin
import Foundation
import XCTest

@testable import AgentSessionManager

final class GitHubCLIRunnerTests: XCTestCase {
    func testGHPathTakesPrecedenceAndReceivesArgumentsAndStdin() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-gh-runner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "gh")
        try "#!/bin/sh\nprintf '%s\\n' \"$@\"\ncat\nprintf stderr >&2\n".write(
            to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let runner = GitHubCLIRunner(environment: [
            "GH_PATH": executable.path,
            "PATH": "/missing",
            "HOME": "/tmp/home",
            "GH_CONFIG_DIR": "/tmp/gh",
        ])
        let result = await runner.run(arguments: ["api", "graphql"], stdin: Data("body".utf8), timeout: 2)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(String(data: result.stdout, encoding: .utf8), "api\ngraphql\nbody")
        XCTAssertEqual(result.stderrPrefix, "stderr")
    }

    func testMissingExecutableAndFailureClassification() async {
        XCTAssertNil(GitHubCLIRunner.resolveExecutable(environment: ["PATH": "/missing"]))
        XCTAssertEqual(GitHubCLIRunner.classify(exitCode: 4, stderr: ""), .authentication)
        XCTAssertEqual(GitHubCLIRunner.classify(exitCode: 2, stderr: ""), .cancelled)
        XCTAssertEqual(GitHubCLIRunner.classify(exitCode: 1, stderr: "no such host"), .network)
        XCTAssertEqual(GitHubCLIRunner.classify(exitCode: 1, stderr: "HTTP/2.0 500"), .api)
    }

    func testExecutableDirectoryIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-gh-runner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executableDirectory = directory.appending(path: "gh")
        try FileManager.default.createDirectory(at: executableDirectory, withIntermediateDirectories: true)

        XCTAssertNil(GitHubCLIRunner.resolveExecutable(environment: ["GH_PATH": executableDirectory.path]))
    }

    func testTimeoutWaitsForReplacementProcessToExit() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-gh-runner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "gh")
        try "#!/bin/sh\nrm \"$0\"\nexec /bin/sleep 2\n".write(
            to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let runner = GitHubCLIRunner(environment: ["GH_PATH": executable.path])
        let start = Date()
        let result = await runner.run(arguments: [], timeout: 0.1)

        XCTAssertEqual(result.failure, .timeout)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }

    func testClosedStdinReportsFailureWithoutTerminatingApp() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-gh-runner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "gh")
        try "#!/bin/sh\nexec 0<&-\nsleep 1\necho unreachable\n".write(
            to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let runner = GitHubCLIRunner(environment: ["GH_PATH": executable.path])

        for _ in 0..<3 {
            let result = await runner.run(
                arguments: [],
                stdin: Data(repeating: 0x61, count: 1_000_000),
                timeout: 2)
            XCTAssertEqual(result.failure, .stdinWrite)
            XCTAssertEqual(result.inputFailure?.stage, .write)
            XCTAssertEqual(result.inputFailure?.errorCode, EPIPE)
        }
    }

    func testClosedStdinPreservesAuthenticationFailure() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-gh-runner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "gh")
        try "#!/bin/sh\nexec 0<&-\nsleep 0.1\necho auth >&2\nexit 4\n".write(
            to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let runner = GitHubCLIRunner(environment: ["GH_PATH": executable.path])

        let result = await runner.run(
            arguments: [],
            stdin: Data(repeating: 0x61, count: 1_000_000),
            timeout: 2)

        XCTAssertEqual(result.failure, .authentication)
        XCTAssertNotNil(result.inputFailure)
    }

    func testCancellationWithStdinReturnsCancelled() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-gh-runner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "gh")
        try "#!/bin/sh\ncat >/dev/null\nexec sleep 5\n".write(
            to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let runner = GitHubCLIRunner(environment: ["GH_PATH": executable.path])

        let task = Task {
            await runner.run(
                arguments: [],
                stdin: Data(repeating: 0x61, count: 1_000_000),
                timeout: 10)
        }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        let result = await task.value
        XCTAssertEqual(result.failure, .cancelled)
    }
}
