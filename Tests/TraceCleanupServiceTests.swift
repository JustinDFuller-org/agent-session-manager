import XCTest

@testable import AgentSessionManager

final class TraceCleanupServiceTests: XCTestCase {
    private var testDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cleanup-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let testDir { try? FileManager.default.removeItem(at: testDir) }
        try await super.tearDown()
    }

    func testOldFilesAreDeleted() throws {
        let subDir = testDir.appendingPathComponent("tab1-abcd1234", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let oldFile = subDir.appendingPathComponent("pane1-efgh5678.jsonl")
        FileManager.default.createFile(atPath: oldFile.path, contents: Data("old data".utf8))

        let twoDaysAgo = Date(timeIntervalSinceNow: -2 * 24 * 3600)
        try FileManager.default.setAttributes([.modificationDate: twoDaysAgo], ofItemAtPath: oldFile.path)

        let (deleted, _) = TraceCleanupService.cleanup(in: testDir, olderThan: 24 * 3600)

        XCTAssertEqual(deleted, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
    }

    func testRecentFilesAreKept() throws {
        let subDir = testDir.appendingPathComponent("tab1-abcd1234", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let recentFile = subDir.appendingPathComponent("pane1-efgh5678.jsonl")
        FileManager.default.createFile(atPath: recentFile.path, contents: Data("recent".utf8))

        let (deleted, _) = TraceCleanupService.cleanup(in: testDir, olderThan: 24 * 3600)

        XCTAssertEqual(deleted, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recentFile.path))
    }

    func testEmptyDirectoriesAreRemovedAfterCleanup() throws {
        let subDir = testDir.appendingPathComponent("tab-empty-dir", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let oldFile = subDir.appendingPathComponent("pane.jsonl")
        FileManager.default.createFile(atPath: oldFile.path, contents: Data("x".utf8))
        let oldDate = Date(timeIntervalSinceNow: -2 * 24 * 3600)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldFile.path)

        let (_, dirsRemoved) = TraceCleanupService.cleanup(in: testDir, olderThan: 24 * 3600)

        XCTAssertEqual(dirsRemoved, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: subDir.path))
    }

    func testNonEmptyDirectoriesAreNotRemoved() throws {
        let subDir = testDir.appendingPathComponent("tab-nonempty", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let oldFile = subDir.appendingPathComponent("old.jsonl")
        let recentFile = subDir.appendingPathComponent("recent.jsonl")
        FileManager.default.createFile(atPath: oldFile.path, contents: Data("x".utf8))
        FileManager.default.createFile(atPath: recentFile.path, contents: Data("y".utf8))
        let oldDate = Date(timeIntervalSinceNow: -2 * 24 * 3600)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldFile.path)

        let (deleted, dirsRemoved) = TraceCleanupService.cleanup(in: testDir, olderThan: 24 * 3600)

        XCTAssertEqual(deleted, 1)
        XCTAssertEqual(dirsRemoved, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: subDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recentFile.path))
    }
}
