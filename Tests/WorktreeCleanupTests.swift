import XCTest
@testable import AgentSessionManager

@MainActor
final class WorktreeCleanupTests: XCTestCase {
    func testPaneWorktreeIsManagedClaudeNoOverride() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appending(path: "asm-worktree-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let managedPath = Tab.worktreeDirectoryURL(repoRoot: tmpDir, name: "test")
        let worktreeDir = managedPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: worktreeDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: managedPath.path, contents: "test".data(using: .utf8))

        let tab = Tab(name: "T", directory: tmpDir)
        let pane = Pane(name: "test", tab: tab, cliType: .claude, claudeDirectoryOverride: nil)
        XCTAssertTrue(pane.worktreeIsManaged)
    }

    func testPaneWorktreeIsManagedClaudeNoOverrideNoWorktreeOnDisk() {
        let tmpDir = FileManager.default.temporaryDirectory
            .appending(path: "asm-worktree-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let tab = Tab(name: "T", directory: tmpDir)
        let pane = Pane(name: "test", tab: tab, cliType: .claude, claudeDirectoryOverride: nil)
        XCTAssertFalse(pane.worktreeIsManaged)
    }

    func testPaneWorktreeIsManagedCodexIsFalse() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .codex, claudeDirectoryOverride: nil)
        XCTAssertFalse(pane.worktreeIsManaged)
    }

    func testPaneWorktreeIsManagedClaudeWithOverrideIsFalse() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let override = URL(filePath: "/some/external/path")
        let pane = Pane(name: "test", tab: tab, cliType: .claude, claudeDirectoryOverride: override)
        XCTAssertFalse(pane.worktreeIsManaged)
    }

    func testWorktreeCleanupBehaviorDisplayNames() {
        XCTAssertEqual(WorktreeCleanupBehavior.ask.displayName, "Ask")
        XCTAssertEqual(WorktreeCleanupBehavior.keep.displayName, "Always Keep")
        XCTAssertEqual(WorktreeCleanupBehavior.delete.displayName, "Always Delete")
    }

    func testWorktreeCleanupBehaviorDescriptions() {
        XCTAssertTrue(WorktreeCleanupBehavior.ask.description.contains("Ask whether"))
        XCTAssertTrue(WorktreeCleanupBehavior.keep.description.contains("Never delete"))
        XCTAssertTrue(WorktreeCleanupBehavior.delete.description.contains("Automatically delete"))
    }

    func testWorktreeCleanupBehaviorCodableRoundTrip() throws {
        let cases: [WorktreeCleanupBehavior] = [.ask, .keep, .delete]
        for behavior in cases {
            let encoded = try JSONEncoder().encode(behavior)
            let decoded = try JSONDecoder().decode(WorktreeCleanupBehavior.self, from: encoded)
            XCTAssertEqual(decoded, behavior)
        }
    }

    func testWorktreeCleanupBehaviorCaseIterable() {
        XCTAssertEqual(WorktreeCleanupBehavior.allCases, [.ask, .keep, .delete])
    }
}

@MainActor
final class WorktreeCleanupGitIntegrationTests: XCTestCase {
    private func makeGitRepo() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "asm-cleanup-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init"], cwd: url)
        try runGit(
            ["-c", "user.email=t@t.com", "-c", "user.name=t", "commit", "--allow-empty", "-m", "init"],
            cwd: url
        )
        try runGit(["branch", "-M", "cleanup-test"], cwd: url)
        return url
    }

    private func runGit(_ args: [String], cwd: URL) throws {
        let p = Process()
        p.executableURL = URL(filePath: "/usr/bin/git")
        p.arguments = args
        p.currentDirectoryURL = cwd
        let err = Pipe()
        p.standardOutput = FileHandle.nullDevice
        p.standardError = err
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("git \(args.joined(separator: " ")): \(msg)")
            throw NSError(domain: "tests", code: Int(p.terminationStatus))
        }
    }

    func testCleanupWorktreeRemovesManagedWorktree() async throws {
        let repo = try makeGitRepo()
        let tab = Tab(name: "CleanupTab", directory: repo)
        let rel = Tab.gitWorktreeAddPath(name: "test-wt")
        try runGit(["worktree", "add", rel, "-b", "cleanup-target", "cleanup-test"], cwd: repo)

        let pane = Pane(name: "test-wt", tab: tab, cliType: .claude, claudeDirectoryOverride: nil)
        XCTAssertTrue(pane.worktreeIsManaged)

        let worktreeURL = Tab.worktreeDirectoryURL(repoRoot: repo, name: "test-wt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreeURL.path))

        try await tab.cleanupWorktree(for: pane)

        XCTAssertFalse(FileManager.default.fileExists(atPath: worktreeURL.path))
    }

    func testCleanupWorktreeNoopsForExternalWorktrees() async throws {
        let repo = try makeGitRepo()
        let tab = Tab(name: "CleanupTab", directory: repo)

        let externalPath = FileManager.default.temporaryDirectory
            .appending(path: "asm-external-wt-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: externalPath, withIntermediateDirectories: true)

        let pane = Pane(name: "external", tab: tab, cliType: .claude, claudeDirectoryOverride: externalPath)
        XCTAssertFalse(pane.worktreeIsManaged)

        try await tab.cleanupWorktree(for: pane)
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalPath.path))

        try FileManager.default.removeItem(at: externalPath)
    }

    func testCleanupWorktreeSkipsWhenPathNotOnDisk() async throws {
        let repo = try makeGitRepo()
        let tab = Tab(name: "CleanupTab", directory: repo)
        let pane = Pane(name: "nonexistent", tab: tab, cliType: .claude, claudeDirectoryOverride: nil)
        XCTAssertFalse(pane.worktreeIsManaged)

        try await tab.cleanupWorktree(for: pane)
    }
}
