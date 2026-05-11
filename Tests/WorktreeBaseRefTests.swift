import XCTest

@testable import AgentSessionManager

@MainActor
final class WorktreeBaseRefTests: XCTestCase {
    func testDefaultIsFresh() {
        let settings = AppSettings()
        XCTAssertEqual(settings.worktreeBaseRef, .fresh)
    }

    func testCodableRoundTrip() throws {
        for ref in WorktreeBaseRef.allCases {
            let encoded = try JSONEncoder().encode(ref)
            let decoded = try JSONDecoder().decode(WorktreeBaseRef.self, from: encoded)
            XCTAssertEqual(decoded, ref)
        }
    }

    func testDisplayNamesAreNonEmpty() {
        for ref in WorktreeBaseRef.allCases {
            XCTAssertFalse(ref.displayName.isEmpty)
        }
    }

    func testDescriptionsAreNonEmpty() {
        for ref in WorktreeBaseRef.allCases {
            XCTAssertFalse(ref.description.isEmpty)
        }
    }

    func testDisplayNames() {
        XCTAssertEqual(WorktreeBaseRef.fresh.displayName, "Fresh")
        XCTAssertEqual(WorktreeBaseRef.head.displayName, "HEAD")
    }

    func testCaseIterable() {
        XCTAssertEqual(WorktreeBaseRef.allCases, [.fresh, .head])
    }
}
