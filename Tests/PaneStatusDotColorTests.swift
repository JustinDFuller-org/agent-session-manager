import SwiftUI
import XCTest

@testable import AgentSessionManager

final class PaneStatusDotColorTests: XCTestCase {
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

    private func runningCheck() -> StatusCheck {
        StatusCheck(name: "ci", status: "IN_PROGRESS", conclusion: nil, detailsUrl: nil)
    }

    private func passingCheck() -> StatusCheck {
        StatusCheck(name: "ci", status: "COMPLETED", conclusion: "SUCCESS", detailsUrl: nil)
    }

    private func failingCheck() -> StatusCheck {
        StatusCheck(name: "ci", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: nil)
    }

    func testPROpenWithCIRunning_returnsYellow() {
        let pr = makePR(state: "open", checks: [runningCheck()])
        XCTAssertEqual(paneStatusDotColor(pr: pr, isMerged: false, processState: nil), .yellow)
    }

    func testPROpenWithCISuccess_returnsGreen() {
        let pr = makePR(state: "open", checks: [passingCheck()])
        XCTAssertEqual(paneStatusDotColor(pr: pr, isMerged: false, processState: nil), .green)
    }

    func testPROpenWithCIFailed_returnsRed() {
        let pr = makePR(state: "open", checks: [failingCheck()])
        XCTAssertEqual(paneStatusDotColor(pr: pr, isMerged: false, processState: nil), .red)
    }

    func testPRMerged_returnsPurple() {
        let pr = makePR(state: "merged")
        XCTAssertEqual(paneStatusDotColor(pr: pr, isMerged: false, processState: nil), .purple)
    }

    func testPRClosed_returnsGray() {
        let pr = makePR(state: "closed")
        XCTAssertEqual(paneStatusDotColor(pr: pr, isMerged: false, processState: nil), .gray)
    }

    func testPROpenWithMergeConflicts_returnsRed() {
        let pr = makePR(state: "open", checks: [passingCheck()], mergeable: "CONFLICTING")
        XCTAssertEqual(paneStatusDotColor(pr: pr, isMerged: false, processState: nil), .red)
    }

    func testPROverridesProcessRunning_whenCIIsYellow() {
        let pr = makePR(state: "open", checks: [runningCheck()])
        XCTAssertEqual(
            paneStatusDotColor(pr: pr, isMerged: false, processState: .running(pid: 1)),
            .yellow
        )
    }

    func testPROverridesIsMerged_whenPRStateIsOpen() {
        let pr = makePR(state: "open", checks: [passingCheck()])
        XCTAssertEqual(paneStatusDotColor(pr: pr, isMerged: true, processState: nil), .green)
    }

    func testIsMergedWithNoPR_returnsPurple() {
        XCTAssertEqual(paneStatusDotColor(pr: nil, isMerged: true, processState: nil), .purple)
    }

    func testIsMergedFalseWithNoPR_andRunning_returnsGreen() {
        XCTAssertEqual(
            paneStatusDotColor(pr: nil, isMerged: false, processState: .running(pid: 1)),
            .green
        )
    }

    func testProcessRunning_returnsGreen() {
        XCTAssertEqual(
            paneStatusDotColor(pr: nil, isMerged: false, processState: .running(pid: 42)),
            .green
        )
    }

    func testProcessExited_returnsGrayOpacity() {
        XCTAssertEqual(
            paneStatusDotColor(pr: nil, isMerged: false, processState: .exited(code: 0)),
            .gray.opacity(0.4)
        )
    }

    func testProcessIdle_returnsGray() {
        XCTAssertEqual(paneStatusDotColor(pr: nil, isMerged: false, processState: .idle), .gray)
    }

    func testProcessNil_returnsGray() {
        XCTAssertEqual(paneStatusDotColor(pr: nil, isMerged: false, processState: nil), .gray)
    }
}
