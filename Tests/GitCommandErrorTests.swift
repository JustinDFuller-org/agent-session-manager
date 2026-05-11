import XCTest

@testable import AgentSessionManager

final class GitCommandErrorTests: XCTestCase {
    func testErrorDescriptionUsesTrimmedStderr() {
        let err = GitCommandError(
            arguments: ["worktree", "add", ".agent-session-manager/worktrees/foo", "bad-ref"],
            exitCode: 128,
            stderr: "fatal: invalid reference: bad-ref\n"
        )
        XCTAssertEqual(err.errorDescription, "fatal: invalid reference: bad-ref")
    }

    func testErrorDescriptionFallbackWhenStderrEmpty() {
        let err = GitCommandError(
            arguments: ["fetch", "origin", "missing"],
            exitCode: 1,
            stderr: "   \n"
        )
        let desc = err.errorDescription ?? ""
        XCTAssertTrue(desc.contains("git exited with status 1"))
        XCTAssertTrue(desc.contains("git fetch origin missing"))
    }
}
