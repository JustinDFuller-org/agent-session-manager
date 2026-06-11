import Foundation
import XCTest

@testable import AgentSessionManager

@MainActor
final class StartupMergedPRCheckTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PersistenceHelpers.overrideAppSupportSubdirectory = "agent-session-manager"
    }

    override func tearDown() {
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        super.tearDown()
    }

    // MARK: - buildStaticBatchQuery

    func testStaticBatchQuerySingleBranch() {
        let paneID = UUID()
        let info = PRTrackingCoordinator.BranchInfo(
            paneID: paneID, owner: "owner", repo: "repo", branch: "feature-1")
        let query = PRTrackingCoordinator.buildStaticBatchQuery(branches: [info])
        let alias = "pane_" + paneID.uuidString.replacingOccurrences(of: "-", with: "")
        XCTAssertTrue(query.contains(alias))
        XCTAssertTrue(query.contains("owner"))
        XCTAssertTrue(query.contains("repo"))
        XCTAssertTrue(query.contains("feature-1"))
        XCTAssertTrue(query.hasPrefix("query BatchedPRStatus"))
        XCTAssertTrue(query.contains("orderBy"), "Query should order results")
        XCTAssertTrue(query.contains("CREATED_AT"), "Query should order by creation date")
        XCTAssertTrue(query.contains("DESC"), "Query should order newest first")
    }

    func testStaticBatchQueryMultipleBranches() {
        let pane1 = UUID()
        let pane2 = UUID()
        let branches = [
            PRTrackingCoordinator.BranchInfo(paneID: pane1, owner: "o1", repo: "r1", branch: "b1"),
            PRTrackingCoordinator.BranchInfo(paneID: pane2, owner: "o2", repo: "r2", branch: "b2"),
        ]
        let query = PRTrackingCoordinator.buildStaticBatchQuery(branches: branches)
        let alias1 = "pane_" + pane1.uuidString.replacingOccurrences(of: "-", with: "")
        let alias2 = "pane_" + pane2.uuidString.replacingOccurrences(of: "-", with: "")
        XCTAssertTrue(query.contains(alias1))
        XCTAssertTrue(query.contains(alias2))
    }

    func testStaticBatchQuerySkipsHEAD() {
        let paneID = UUID()
        let info = PRTrackingCoordinator.BranchInfo(
            paneID: paneID, owner: "o", repo: "r", branch: "HEAD")
        let query = PRTrackingCoordinator.buildStaticBatchQuery(branches: [info])
        XCTAssertTrue(query.isEmpty)
    }

    func testStaticBatchQuerySkipsEmptyBranch() {
        let paneID = UUID()
        let info = PRTrackingCoordinator.BranchInfo(
            paneID: paneID, owner: "o", repo: "r", branch: "")
        let query = PRTrackingCoordinator.buildStaticBatchQuery(branches: [info])
        XCTAssertTrue(query.isEmpty)
    }

    func testStaticBatchQueryEmptyInput() {
        let query = PRTrackingCoordinator.buildStaticBatchQuery(branches: [])
        XCTAssertTrue(query.isEmpty)
    }

    // MARK: - parseStaticBatchResponse

    func testParseStaticBatchResponseMergedPR() {
        let paneID = UUID()
        let alias = "pane_" + paneID.uuidString.replacingOccurrences(of: "-", with: "")
        let json = """
            {
              "data": {
                "\(alias)": {
                  "pullRequests": {
                    "nodes": [{
                      "number": 42,
                      "title": "My feature",
                      "state": "MERGED",
                      "url": "https://github.com/o/r/pull/42",
                      "isDraft": false,
                      "mergeable": "UNKNOWN"
                    }]
                  }
                }
              }
            }
            """
        let branches = [
            PRTrackingCoordinator.BranchInfo(paneID: paneID, owner: "o", repo: "r", branch: "feature")
        ]
        let results = PRTrackingCoordinator.parseStaticBatchResponse(json, branches: branches)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].paneID, paneID)
        XCTAssertEqual(results[0].pr.number, 42)
        XCTAssertEqual(results[0].pr.state, "merged")
        XCTAssertEqual(results[0].pr.title, "My feature")
    }

    func testParseStaticBatchResponseOpenPR() {
        let paneID = UUID()
        let alias = "pane_" + paneID.uuidString.replacingOccurrences(of: "-", with: "")
        let json = """
            {
              "data": {
                "\(alias)": {
                  "pullRequests": {
                    "nodes": [{
                      "number": 10,
                      "title": "WIP",
                      "state": "OPEN",
                      "url": "https://github.com/o/r/pull/10"
                    }]
                  }
                }
              }
            }
            """
        let branches = [
            PRTrackingCoordinator.BranchInfo(paneID: paneID, owner: "o", repo: "r", branch: "wip")
        ]
        let results = PRTrackingCoordinator.parseStaticBatchResponse(json, branches: branches)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pr.state, "open")
    }

    func testParseStaticBatchResponseNoPR() {
        let paneID = UUID()
        let alias = "pane_" + paneID.uuidString.replacingOccurrences(of: "-", with: "")
        let json = """
            {
              "data": {
                "\(alias)": {
                  "pullRequests": {
                    "nodes": []
                  }
                }
              }
            }
            """
        let branches = [
            PRTrackingCoordinator.BranchInfo(paneID: paneID, owner: "o", repo: "r", branch: "no-pr")
        ]
        let results = PRTrackingCoordinator.parseStaticBatchResponse(json, branches: branches)
        XCTAssertTrue(results.isEmpty)
    }

    func testParseStaticBatchResponseInvalidJSON() {
        let branches = [
            PRTrackingCoordinator.BranchInfo(paneID: UUID(), owner: "o", repo: "r", branch: "b")
        ]
        let results = PRTrackingCoordinator.parseStaticBatchResponse("not json", branches: branches)
        XCTAssertTrue(results.isEmpty)
    }

    func testParseStaticBatchResponseMultiplePanes() {
        let pane1 = UUID()
        let pane2 = UUID()
        let alias1 = "pane_" + pane1.uuidString.replacingOccurrences(of: "-", with: "")
        let alias2 = "pane_" + pane2.uuidString.replacingOccurrences(of: "-", with: "")
        let json = """
            {
              "data": {
                "\(alias1)": {
                  "pullRequests": {
                    "nodes": [{
                      "number": 1, "title": "PR1", "state": "MERGED", "url": "u1"
                    }]
                  }
                },
                "\(alias2)": {
                  "pullRequests": {
                    "nodes": [{
                      "number": 2, "title": "PR2", "state": "OPEN", "url": "u2"
                    }]
                  }
                }
              }
            }
            """
        let branches = [
            PRTrackingCoordinator.BranchInfo(paneID: pane1, owner: "o", repo: "r", branch: "b1"),
            PRTrackingCoordinator.BranchInfo(paneID: pane2, owner: "o", repo: "r", branch: "b2"),
        ]
        let results = PRTrackingCoordinator.parseStaticBatchResponse(json, branches: branches)
        XCTAssertEqual(results.count, 2)
        let mergedResults = results.filter { $0.pr.state == "merged" }
        XCTAssertEqual(mergedResults.count, 1)
        XCTAssertEqual(mergedResults[0].paneID, pane1)
    }

    // MARK: - BranchInfo

    func testBranchInfoStoresFields() {
        let id = UUID()
        let info = PRTrackingCoordinator.BranchInfo(
            paneID: id, owner: "myowner", repo: "myrepo", branch: "mybranch")
        XCTAssertEqual(info.paneID, id)
        XCTAssertEqual(info.owner, "myowner")
        XCTAssertEqual(info.repo, "myrepo")
        XCTAssertEqual(info.branch, "mybranch")
    }

    // MARK: - checkForMergedPRsAfterRestore candidate filtering

    func testStartupCheckSkipsAlreadyMergedPanes() async {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "feature", worktreeDirectory: URL(fileURLWithPath: "/tmp/wt"))
        pane.isMerged = true
        state.tabs.append(tab)

        await SessionPersistence.checkForMergedPRsAfterRestore(appState: state)

        XCTAssertTrue(state.notifications.isEmpty, "Should not query for already-merged panes")
    }

    func testStartupCheckSkipsPanesWithoutWorktreeDirectory() async {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        _ = tab.addPane(name: "feature")
        state.tabs.append(tab)

        await SessionPersistence.checkForMergedPRsAfterRestore(appState: state)

        XCTAssertTrue(state.notifications.isEmpty, "Should skip panes without worktree directory")
    }

    func testStartupCheckDoesNothingWithNoPanes() async {
        let state = AppState()
        await SessionPersistence.checkForMergedPRsAfterRestore(appState: state)
        XCTAssertTrue(state.notifications.isEmpty)
    }
}
