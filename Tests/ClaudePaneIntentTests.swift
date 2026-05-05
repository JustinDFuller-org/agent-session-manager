import XCTest
@testable import AgentSessionManager

@MainActor
final class ClaudePaneIntentTests: XCTestCase {

    private func makeGitRepo() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "asm-claude-intent-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init"], cwd: url)
        try runGit(
            ["-c", "user.email=t@t.com", "-c", "user.name=t", "commit", "--allow-empty", "-m", "init"],
            cwd: url
        )
        // Stable name (defaults vary between main/master depending on Git version).
        try runGit(["branch", "-M", "intent-test-branch"], cwd: url)
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

    private func currentBranch(cwd: URL) throws -> String {
        let p = Process()
        p.executableURL = URL(filePath: "/usr/bin/git")
        p.arguments = ["branch", "--show-current"]
        p.currentDirectoryURL = cwd
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testNovelSimpleNameDelegatesToClaudeWorktreeFlag() async throws {
        let repo = try makeGitRepo()
        let tab = Tab(name: "T", directory: repo)
        let slug = UUID().uuidString.prefix(8)
        let intent = try await tab.classifyClaudePaneIntent(userRef: "fresh-session-\(slug)")
        guard case let .claudeWorktreeFlag(name) = intent else {
            XCTFail("expected claudeWorktreeFlag, got \(intent)")
            return
        }
        XCTAssertEqual(name, "fresh-session-\(slug)")
    }

    func testLooseBranchRefUsesResolveViaApp() async throws {
        let repo = try makeGitRepo()
        // Branch exists locally but isn’t tied to another worktree line (still only primary checkout listed).
        try runGit(["branch", "loose-branch", "HEAD"], cwd: repo)

        let tab = Tab(name: "T", directory: repo)
        let intent = try await tab.classifyClaudePaneIntent(userRef: "loose-branch")
        guard case let .resolveViaApp(raw) = intent else {
            XCTFail("expected resolveViaApp, got \(intent)")
            return
        }
        XCTAssertEqual(raw, "loose-branch")
    }

    func testPrimaryCheckoutBranchOffersReuseConfirmation() async throws {
        let repo = try makeGitRepo()
        let branch = try currentBranch(cwd: repo)
        XCTAssertEqual(branch, "intent-test-branch")
        let tab = Tab(name: "T", directory: repo)
        let intent = try await tab.classifyClaudePaneIntent(userRef: branch)
        guard case let .reuse(_, rawInput, _) = intent else {
            XCTFail("expected reuse opening existing checkout, got \(intent)")
            return
        }
        XCTAssertEqual(rawInput, branch)
    }
    func testRemoteStyleRefUsesResolveViaAppWithoutLocalMatch() async throws {
        let repo = try makeGitRepo()
        let tab = Tab(name: "T", directory: repo)
        let intent = try await tab.classifyClaudePaneIntent(userRef: "origin/nonexistent-branch-xyz")
        guard case let .resolveViaApp(raw) = intent else {
            XCTFail("expected resolveViaApp, got \(intent)")
            return
        }
        XCTAssertEqual(raw, "origin/nonexistent-branch-xyz")
    }

    func testExistingAppManagedLinkedWorktreeUsesReuse() async throws {
        let repo = try makeGitRepo()
        let branch = try currentBranch(cwd: repo)
        XCTAssertEqual(branch, "intent-test-branch")
        let rel = Tab.gitWorktreeAddPath(name: "wt-sidecar")
        try runGit(["worktree", "add", rel, "-b", "wt-sidecar-tracking", branch], cwd: repo)

        let tab = Tab(name: "T", directory: repo)
        let intent = try await tab.classifyClaudePaneIntent(userRef: "wt-sidecar")
        guard case let .reuse(_, rawInput, resolved) = intent else {
            XCTFail("expected reuse, got \(intent)")
            return
        }
        XCTAssertEqual(rawInput, "wt-sidecar")
        XCTAssertNil(resolved.claudeProcessDirectory)
        XCTAssertTrue(resolved.checkoutURL.path.hasSuffix(rel))
    }
}
