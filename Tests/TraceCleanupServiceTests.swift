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

        // Set mtime to 2 days ago
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
        // mtime is now (default), which is within 24h

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
        // One old file (will be deleted), one recent file (kept)
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

    func testRotatedGenerationIsDeletedLikeAnyOtherJSONLFile() throws {
        let subDir = testDir.appendingPathComponent("tab1-abcd1234", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let rotatedFile = subDir.appendingPathComponent("pane1-efgh5678.1.jsonl")
        FileManager.default.createFile(atPath: rotatedFile.path, contents: Data("old generation".utf8))
        let oldDate = Date(timeIntervalSinceNow: -2 * 24 * 3600)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: rotatedFile.path)

        let (deleted, _) = TraceCleanupService.cleanup(in: testDir, olderThan: 24 * 3600)

        XCTAssertEqual(deleted, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: rotatedFile.path))
    }

    func testStaleAtomicWriteOrphanIsReclaimed() throws {
        let subDir = testDir.appendingPathComponent("_global", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let orphan = subDir.appendingPathComponent("global.jsonl.sb-1234-abcdef")
        FileManager.default.createFile(atPath: orphan.path, contents: Data("partial write".utf8))
        let staleDate = Date(timeIntervalSinceNow: -600)
        try FileManager.default.setAttributes([.modificationDate: staleDate], ofItemAtPath: orphan.path)

        let (deleted, _) = TraceCleanupService.cleanup(in: testDir, olderThan: 24 * 3600)

        XCTAssertEqual(deleted, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }

    func testFreshAtomicWriteOrphanIsNotReclaimedYet() throws {
        let subDir = testDir.appendingPathComponent("_global", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let inFlight = subDir.appendingPathComponent("global.jsonl.sb-9999-fedcba")
        FileManager.default.createFile(atPath: inFlight.path, contents: Data("in flight".utf8))
        // mtime is now (default), well under the 300s atomic-write staleness threshold

        let (deleted, _) = TraceCleanupService.cleanup(in: testDir, olderThan: 24 * 3600)

        XCTAssertEqual(deleted, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: inFlight.path))
    }

    func testCleanupFlatDirectoryDeletesOldJSONLFiles() throws {
        let invariantsDir = testDir.appendingPathComponent("invariants", isDirectory: true)
        try FileManager.default.createDirectory(at: invariantsDir, withIntermediateDirectories: true)
        let active = invariantsDir.appendingPathComponent("invariants.jsonl")
        let rotated = invariantsDir.appendingPathComponent("invariants.1.jsonl")
        FileManager.default.createFile(atPath: active.path, contents: Data("recent".utf8))
        FileManager.default.createFile(atPath: rotated.path, contents: Data("old".utf8))
        let oldDate = Date(timeIntervalSinceNow: -2 * 24 * 3600)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: rotated.path)

        let deleted = TraceCleanupService.cleanupFlatDirectory(at: invariantsDir, olderThan: 24 * 3600)

        XCTAssertEqual(deleted, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: active.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: rotated.path))
    }

    func testReclaimLegacyRootFilesDeletesOnlyWhatExists() throws {
        try Data("stale".utf8).write(to: testDir.appendingPathComponent("debug-trace.log"))

        let reclaimed = TraceCleanupService.reclaimLegacyRootFiles(supportDirectory: testDir)

        XCTAssertEqual(reclaimed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDir.appendingPathComponent("debug-trace.log").path))
    }
}
