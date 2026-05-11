import XCTest

@testable import AgentSessionManager

final class WorktreeListParserTests: XCTestCase {
    func testParseSingleWorktreeWithBranch() {
        let out = """
            worktree /Users/me/project
            HEAD abc123def456789
            branch refs/heads/main

            """
        let entries = Tab.parseWorktreeListPorcelain(out)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "/Users/me/project")
        XCTAssertEqual(entries[0].branch, "refs/heads/main")
    }

    func testParseTwoWorktrees() {
        let out = """
            worktree /repo
            HEAD aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
            branch refs/heads/main

            worktree /repo/.agent-session-manager/worktrees/feat
            HEAD bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
            branch refs/heads/feature

            """
        let entries = Tab.parseWorktreeListPorcelain(out)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[1].path, "/repo/.agent-session-manager/worktrees/feat")
        XCTAssertEqual(entries[1].branch, "refs/heads/feature")
    }

    func testParseDetached() {
        let out = """
            worktree /tmp/detached
            HEAD cccccccccccccccccccccccccccccccccccccccc
            detached

            """
        let entries = Tab.parseWorktreeListPorcelain(out)
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries[0].branch)
    }

    func testRefMatchesShortBranchName() {
        XCTAssertTrue(Tab.refMatches(userRef: "main", branchRef: "refs/heads/main"))
        XCTAssertTrue(Tab.refMatches(userRef: "feature", branchRef: "refs/heads/feature"))
    }

    func testRefMatchesRemoteStyle() {
        XCTAssertTrue(Tab.refMatches(userRef: "origin/foo", branchRef: "refs/remotes/origin/foo"))
    }

    func testDerivedWorktreeNameFromRemoteRef() {
        XCTAssertEqual(Tab.derivedWorktreeName(fromRef: "refs/remotes/origin/my-feature"), "my-feature")
        XCTAssertEqual(Tab.derivedWorktreeName(fromRef: "dependabot/go_modules/foo"), "foo")
    }

    func testGitWorktreeAddPath() {
        XCTAssertEqual(Tab.gitWorktreeAddPath(name: "auth-fix"), ".agent-session-manager/worktrees/auth-fix")
    }

    /// When a branch name equals one folder and another folder’s name equals the typed ref, pick by folder.
    func testPreferWorktreeEntryDirectoryNameBeforeBranch() {
        let entries = Tab.parseWorktreeListPorcelain(
            """
            worktree /Users/me/meter-go
            HEAD 1111111111111111111111111111111111111111
            branch refs/heads/main

            worktree /Users/me/meter-go/.claude/worktrees/meter-chore-claude-review
            HEAD 2222222222222222222222222222222222222222
            branch refs/heads/worktree-meter-chore-claude-review

            worktree /Users/me/meter-go/.claude/worktrees/worktree-meter-chore-claude-review
            HEAD 3333333333333333333333333333333333333333
            branch refs/heads/worktree-worktree-meter-chore-claude-review

            """
        )
        let picked = Tab.preferWorktreeEntry(matchingUserRef: "worktree-meter-chore-claude-review", entries: entries)
        XCTAssertEqual(
            picked?.path,
            "/Users/me/meter-go/.claude/worktrees/worktree-meter-chore-claude-review"
        )
    }

    func testPreferWorktreeEntryFallsBackToBranch() {
        let entries = Tab.parseWorktreeListPorcelain(
            """
            worktree /Users/me/project
            HEAD 1111111111111111111111111111111111111111
            branch refs/heads/main

            worktree /Users/me/project/.claude/worktrees/feature-a
            HEAD 2222222222222222222222222222222222222222
            branch refs/heads/feature-a

            """
        )
        let picked = Tab.preferWorktreeEntry(matchingUserRef: "feature-a", entries: entries)
        XCTAssertEqual(picked?.path, "/Users/me/project/.claude/worktrees/feature-a")
    }
}
