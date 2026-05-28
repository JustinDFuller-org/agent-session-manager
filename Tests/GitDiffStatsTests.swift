import XCTest

@testable import AgentSessionManager

final class GitDiffStatsTests: XCTestCase {
    func testParseFullOutput() {
        let output = " 1 file changed, 3 insertions(+), 2 deletions(-)"
        let result = GitDiffStats.parse(output)
        XCTAssertEqual(result.added, 3)
        XCTAssertEqual(result.removed, 2)
    }

    func testParseInsertionsOnly() {
        let output = " 1 file changed, 5 insertions(+)"
        let result = GitDiffStats.parse(output)
        XCTAssertEqual(result.added, 5)
        XCTAssertEqual(result.removed, 0)
    }

    func testParseDeletionsOnly() {
        let output = " 1 file changed, 2 deletions(-)"
        let result = GitDiffStats.parse(output)
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.removed, 2)
    }

    func testParseEmptyOutput() {
        let result = GitDiffStats.parse("")
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.removed, 0)
    }

    func testParseMalformedOutput() {
        let result = GitDiffStats.parse("not a valid shortstat line")
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.removed, 0)
    }

    func testParseMultiFileOutput() {
        let output = " 3 files changed, 12 insertions(+), 7 deletions(-)"
        let result = GitDiffStats.parse(output)
        XCTAssertEqual(result.added, 12)
        XCTAssertEqual(result.removed, 7)
    }

    func testComputeInGitDirectory() async {
        let sourceDir = #file.components(separatedBy: "/Tests/").first ?? "."
        let result = await GitDiffStats.compute(in: sourceDir)
        XCTAssertNotNil(result, "Should succeed in a valid git directory")
    }

    func testComputeInNonGitDirectory() async {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let result = await GitDiffStats.compute(in: tmpDir.path)
        XCTAssertNil(result, "Non-git directory should return nil")
    }
}
