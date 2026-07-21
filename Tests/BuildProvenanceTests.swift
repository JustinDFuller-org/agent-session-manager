import XCTest

@testable import AgentSessionManager

final class BuildProvenanceTests: XCTestCase {
    func testMainBranchIsMainSourceBuild() {
        let provenance = BuildProvenance.from(infoDictionary: [
            "ASMSourceCommit": "abc123",
            "ASMSourceBranch": "main",
            "ASMSourceCommitDate": "2024-01-01T12:00:00-07:00",
        ])
        XCTAssertEqual(provenance?.commit, "abc123")
        XCTAssertEqual(provenance?.branch, "main")
        XCTAssertNotNil(provenance?.commitDate)
        XCTAssertTrue(provenance?.isMainSourceBuild ?? false)
    }

    func testFeatureBranchIsNotMainSourceBuild() {
        let provenance = BuildProvenance.from(infoDictionary: [
            "ASMSourceCommit": "abc123",
            "ASMSourceBranch": "update-available",
        ])
        XCTAssertFalse(provenance?.isMainSourceBuild ?? true)
    }

    func testMissingKeysReturnsNil() {
        XCTAssertNil(BuildProvenance.from(infoDictionary: [:]))
    }

    func testEmptyCommitReturnsNil() {
        let provenance = BuildProvenance.from(infoDictionary: [
            "ASMSourceCommit": "",
            "ASMSourceBranch": "main",
        ])
        XCTAssertNil(provenance)
    }

    func testMissingCommitDateIsNil() {
        let provenance = BuildProvenance.from(infoDictionary: [
            "ASMSourceCommit": "abc123",
            "ASMSourceBranch": "main",
        ])
        XCTAssertNotNil(provenance)
        XCTAssertNil(provenance?.commitDate)
    }
}
