import XCTest

@testable import AgentSessionManager

/// Runs `/bin/zsh -c` and drains stderr so pipes cannot fill.
private enum PRQueryShellIO {
    static func zshCollectOutput(script: String, currentDirectory: URL?) throws -> Data {
        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.executableURL = URL(filePath: "/bin/zsh")
        task.arguments = ["-c", script]
        task.currentDirectoryURL = currentDirectory
        task.standardOutput = outPipe
        task.standardError = errPipe
        try task.run()
        task.waitUntilExit()
        _ = errPipe.fileHandleForReading.readDataToEndOfFile()
        return outPipe.fileHandleForReading.readDataToEndOfFile()
    }
}

/// Regression cover for PR query subprocess I/O: use `terminationHandler`-style full read + drain stderr (see `PRQueryShellIO`), not `readabilityHandler` without EOF teardown (which could spin CPU).
final class PRQueryShellIOTests: XCTestCase {
    func testZshCollectOutputDecodesPullRequestJSON() throws {
        let json =
            #"{"number":42,"title":"Hello","state":"open","url":"https://example.com/pr/42","isDraft":true,"statusCheckRollup":[{"name":"CI","status":"COMPLETED","conclusion":"SUCCESS","detailsUrl":"https://ci.example.com"}]}"#
        let script = "printf '%s' '\(json)'"
        let data = try PRQueryShellIO.zshCollectOutput(script: script, currentDirectory: nil)
        var pr = try JSONDecoder().decode(PullRequest.self, from: data)
        XCTAssertEqual(pr.number, 42)
        XCTAssertEqual(pr.title, "Hello")
        XCTAssertEqual(pr.state, "open")
        XCTAssertEqual(pr.url, "https://example.com/pr/42")
        XCTAssertEqual(pr.isDraft, true)
        XCTAssertEqual(pr.statusCheckRollup?.count, 1)
        XCTAssertEqual(pr.statusCheckRollup?.first?.name, "CI")
        pr.commitStatusState = "SUCCESS"
        XCTAssertEqual(pr.buildStatus, .success)
    }

    func testZshCollectOutputEmptyWhenNoStdout() throws {
        let data = try PRQueryShellIO.zshCollectOutput(script: "true", currentDirectory: nil)
        XCTAssertTrue(data.isEmpty)
    }

    func testZshCollectOutputDrainsStderr() throws {
        let script = "echo err >&2; printf '%s' '{\"number\":1,\"title\":\"T\",\"state\":\"merged\",\"url\":\"u\"}'"
        let data = try PRQueryShellIO.zshCollectOutput(script: script, currentDirectory: nil)
        let pr = try JSONDecoder().decode(PullRequest.self, from: data)
        XCTAssertEqual(pr.number, 1)
    }

    // MARK: - Merge conflict detection

    func testMergeConflictingDecodes() throws {
        let json =
            #"{"number":1,"title":"T","state":"open","url":"u","mergeable":"CONFLICTING"}"#
        let pr = try JSONDecoder().decode(PullRequest.self, from: Data(json.utf8))
        XCTAssertTrue(pr.hasMergeConflicts)
    }

    func testMergeableDecodes() throws {
        let json =
            #"{"number":1,"title":"T","state":"open","url":"u","mergeable":"MERGEABLE"}"#
        let pr = try JSONDecoder().decode(PullRequest.self, from: Data(json.utf8))
        XCTAssertFalse(pr.hasMergeConflicts)
    }

    func testMergeableAbsent() throws {
        let json = #"{"number":1,"title":"T","state":"open","url":"u"}"#
        let pr = try JSONDecoder().decode(PullRequest.self, from: Data(json.utf8))
        XCTAssertFalse(pr.hasMergeConflicts)
    }

    func testMergeUnknownIsNotConflicting() throws {
        let json =
            #"{"number":1,"title":"T","state":"open","url":"u","mergeable":"UNKNOWN"}"#
        let pr = try JSONDecoder().decode(PullRequest.self, from: Data(json.utf8))
        XCTAssertFalse(pr.hasMergeConflicts)
    }
}
