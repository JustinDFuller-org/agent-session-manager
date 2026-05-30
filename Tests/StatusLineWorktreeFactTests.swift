import XCTest

@testable import AgentSessionManager

final class StatusLineWorktreeFactTests: XCTestCase {
    func testFactTextWithNameAndBranch() {
        let worktree = StatusLineData.Worktree(name: "foo", branch: "main")
        XCTAssertEqual(worktree.factText, "foo • main")
    }

    func testFactTextWithNameOnly() {
        let worktree = StatusLineData.Worktree(name: "foo", branch: nil)
        XCTAssertEqual(worktree.factText, "foo")
    }

    func testFactTextWithNilName() {
        let worktree = StatusLineData.Worktree(name: nil, branch: "main")
        XCTAssertEqual(worktree.factText, "—")
    }

    func testFactTextWithBothNil() {
        let worktree = StatusLineData.Worktree(name: nil, branch: nil)
        XCTAssertEqual(worktree.factText, "—")
    }

    func testWorktreeBranchIsAbsentFromCatalog() {
        XCTAssertNil(StatusLineConfig.itemMetadata["worktreeBranch"])
        XCTAssertNil(StatusLineConfig.itemAvailability["worktreeBranch"])
        XCTAssertFalse(StatusLineConfig.itemOrder.contains("worktreeBranch"))
    }
}
