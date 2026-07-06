import XCTest

@testable import AgentSessionManager

final class UpdateCheckLogicTests: XCTestCase {
    func testParseCommitSHA() {
        let sha = String(repeating: "a", count: 40)
        XCTAssertEqual(UpdateCheckCoordinator.parseCommitSHA("\(sha)\n"), sha)
    }

    func testParseCommitSHAWithoutTrailingNewline() {
        let sha = String(repeating: "b", count: 40)
        XCTAssertEqual(UpdateCheckCoordinator.parseCommitSHA(sha), sha)
    }

    func testParseCommitSHATrimsWhitespace() {
        let sha = String(repeating: "c", count: 40)
        XCTAssertEqual(UpdateCheckCoordinator.parseCommitSHA("  \(sha)  \n"), sha)
    }

    func testParseCommitSHAEmptyOutputReturnsNil() {
        XCTAssertNil(UpdateCheckCoordinator.parseCommitSHA(""))
    }

    func testParseCommitSHAGarbageReturnsNil() {
        XCTAssertNil(UpdateCheckCoordinator.parseCommitSHA("not a valid sha"))
    }

    func testParseCommitSHAShortShaReturnsNil() {
        XCTAssertNil(UpdateCheckCoordinator.parseCommitSHA("abc123"))
    }

    func testIsUpdateAvailableWhenCommitsDiffer() {
        XCTAssertTrue(UpdateCheckCoordinator.isUpdateAvailable(builtCommit: "aaa", latestCommit: "bbb"))
    }

    func testIsUpdateAvailableWhenCommitsMatch() {
        XCTAssertFalse(UpdateCheckCoordinator.isUpdateAvailable(builtCommit: "aaa", latestCommit: "aaa"))
    }
}
