import SwiftUI
import XCTest

@testable import AgentSessionManager

final class PullRequestColorTests: XCTestCase {
    private func makePR(
        state: String,
        checks: [StatusCheck]? = nil,
        mergeable: String? = nil
    ) -> PullRequest {
        PullRequest(
            number: 1,
            title: "Test PR",
            state: state,
            url: "https://github.com/owner/repo/pull/1",
            statusCheckRollup: checks,
            mergeable: mergeable
        )
    }

    private func failingCheck() -> StatusCheck {
        StatusCheck(name: "ci", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: nil)
    }

    private func passingCheck() -> StatusCheck {
        StatusCheck(name: "ci", status: "COMPLETED", conclusion: "SUCCESS", detailsUrl: nil)
    }

    func testMergedWithFailingCI() {
        let pr = makePR(state: "merged", checks: [failingCheck()])
        XCTAssertEqual(pr.circleColor, .purple)
    }

    func testMergedWithNoCI() {
        let pr = makePR(state: "merged")
        XCTAssertEqual(pr.circleColor, .purple)
    }

    func testMergedWithPassingCI() {
        let pr = makePR(state: "merged", checks: [passingCheck()])
        XCTAssertEqual(pr.circleColor, .purple)
    }

    func testClosedWithFailingCI() {
        let pr = makePR(state: "closed", checks: [failingCheck()])
        XCTAssertEqual(pr.circleColor, .gray)
    }

    func testClosedWithNoCI() {
        let pr = makePR(state: "closed")
        XCTAssertEqual(pr.circleColor, .gray)
    }

    func testOpenWithFailingCI() {
        let pr = makePR(state: "open", checks: [failingCheck()])
        XCTAssertEqual(pr.circleColor, .red)
    }

    func testOpenWithPassingCI() {
        let pr = makePR(state: "open", checks: [passingCheck()])
        XCTAssertEqual(pr.circleColor, .green)
    }

    func testOpenWithRunningCI() {
        let pr = makePR(
            state: "open",
            checks: [StatusCheck(name: "ci", status: "IN_PROGRESS", conclusion: nil, detailsUrl: nil)])
        XCTAssertEqual(pr.circleColor, .yellow)
    }

    func testOpenWithMergeConflicts() {
        let pr = makePR(state: "open", checks: [passingCheck()], mergeable: "CONFLICTING")
        XCTAssertEqual(pr.circleColor, .red)
    }

    func testOpenWithNoCI() {
        let pr = makePR(state: "open")
        XCTAssertEqual(pr.circleColor, .secondary)
    }
}
