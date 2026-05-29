import XCTest

@testable import AgentSessionManager

final class StatusLineWorktreeChipTests: XCTestCase {
    func testChipTextWithNameAndBranch() {
        let worktree = StatusLineData.Worktree(name: "foo", branch: "main")
        XCTAssertEqual(worktree.chipText, "foo • main")
    }

    func testChipTextWithNameOnly() {
        let worktree = StatusLineData.Worktree(name: "foo", branch: nil)
        XCTAssertEqual(worktree.chipText, "foo")
    }

    func testChipTextWithNilName() {
        let worktree = StatusLineData.Worktree(name: nil, branch: "main")
        XCTAssertEqual(worktree.chipText, "—")
    }

    func testChipTextWithBothNil() {
        let worktree = StatusLineData.Worktree(name: nil, branch: nil)
        XCTAssertEqual(worktree.chipText, "—")
    }

    func testWorktreeBranchIsAbsentFromCatalog() {
        XCTAssertNil(StatusLineConfig.itemMetadata["worktreeBranch"])
        XCTAssertNil(StatusLineConfig.itemAvailability["worktreeBranch"])
        XCTAssertFalse(StatusLineConfig.itemOrder.contains("worktreeBranch"))
    }
}
