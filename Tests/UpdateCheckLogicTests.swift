import XCTest

@testable import AgentSessionManager

final class UpdateCheckLogicTests: XCTestCase {
    func testParseCommitSHA() {
        let sha = String(repeating: "a", count: 40)
        XCTAssertEqual(MainBranchUpdateDetector.parseCommitSHA("\(sha)\n"), sha)
    }

    func testParseCommitSHAWithoutTrailingNewline() {
        let sha = String(repeating: "b", count: 40)
        XCTAssertEqual(MainBranchUpdateDetector.parseCommitSHA(sha), sha)
    }

    func testParseCommitSHATrimsWhitespace() {
        let sha = String(repeating: "c", count: 40)
        XCTAssertEqual(MainBranchUpdateDetector.parseCommitSHA("  \(sha)  \n"), sha)
    }

    func testParseCommitSHAEmptyOutputReturnsNil() {
        XCTAssertNil(MainBranchUpdateDetector.parseCommitSHA(""))
    }

    func testParseCommitSHAGarbageReturnsNil() {
        XCTAssertNil(MainBranchUpdateDetector.parseCommitSHA("not a valid sha"))
    }

    func testParseCommitSHAShortShaReturnsNil() {
        XCTAssertNil(MainBranchUpdateDetector.parseCommitSHA("abc123"))
    }

    func testIsUpdateAvailableWhenCommitsDiffer() {
        XCTAssertTrue(MainBranchUpdateDetector.isUpdateAvailable(builtCommit: "aaa", latestCommit: "bbb"))
    }

    func testIsUpdateAvailableWhenCommitsMatch() {
        XCTAssertFalse(MainBranchUpdateDetector.isUpdateAvailable(builtCommit: "aaa", latestCommit: "aaa"))
    }
}
