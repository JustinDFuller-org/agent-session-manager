import XCTest
import os

@testable import AgentSessionManager

final class AppLogTests: XCTestCase {
    func testCategoryForSpanNameMapsKnownPrefixes() {
        XCTAssertEqual(AppLog.category(forSpanName: "terminal.process.started"), .terminal)
        XCTAssertEqual(AppLog.category(forSpanName: "pane.created"), .pane)
        XCTAssertEqual(AppLog.category(forSpanName: "tab.worktree.base_branch_resolved"), .tab)
        XCTAssertEqual(AppLog.category(forSpanName: "pr.poll.cycle"), .pr)
        XCTAssertEqual(AppLog.category(forSpanName: "statusline.worktree.name_mismatch"), .statusline)
        XCTAssertEqual(AppLog.category(forSpanName: "notification.delivered"), .notification)
        XCTAssertEqual(AppLog.category(forSpanName: "session.restored"), .session)
        XCTAssertEqual(AppLog.category(forSpanName: "invariant.violated"), .invariant)
    }

    func testCategoryForSpanNameFallsBackToAppForUnknownPrefixes() {
        XCTAssertEqual(AppLog.category(forSpanName: "trace.cleanup.ran"), .app)
        XCTAssertEqual(AppLog.category(forSpanName: "window.snapshot"), .app)
        XCTAssertEqual(AppLog.category(forSpanName: "unknown_category_event"), .app)
    }

    func testOsLogTypeMapsInvariantSeverity() {
        XCTAssertEqual(AppLog.osLogType(for: .warning), .default)
        XCTAssertEqual(AppLog.osLogType(for: .error), .error)
    }
}
