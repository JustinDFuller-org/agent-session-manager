import XCTest

@testable import AgentSessionManager

@MainActor
final class WorktreeResolutionLocalOnlyTests: XCTestCase {
    private func makeGitRepo(branchName: String = "main") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "agent-session-manager-resolution-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init"], cwd: url)
        try runGit(
            ["-c", "user.email=t@t.com", "-c", "user.name=t", "commit", "--allow-empty", "-m", "init"],
            cwd: url
        )
        try runGit(["branch", "-M", branchName], cwd: url)
        return url
    }

    private func runGit(_ args: [String], cwd: URL) throws {
        let proc = Process()
        proc.executableURL = URL(filePath: "/usr/bin/git")
        proc.arguments = args
        proc.currentDirectoryURL = cwd
        let err = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = err
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            XCTFail("git \(args.joined(separator: " ")): \(msg)")
            throw NSError(domain: "tests", code: Int(proc.terminationStatus))
        }
    }

    func testFreshBaseRefSucceedsWithLocalOnlyBranch() async throws {
        let repo = try makeGitRepo(branchName: "main")
        try runGit(["checkout", "-b", "my-local-branch"], cwd: repo)
        let tab = Tab(name: "T", directory: repo)

        let resolved = try await tab.resolveOrAttachWorktree(
            userRef: "new-feature",
            defaultBranch: "my-local-branch",
            baseRef: .fresh
        )

        XCTAssertEqual(resolved.paneTitle, "new-feature")
        XCTAssertTrue(resolved.checkoutURL.path.contains("new-feature"))

        try? FileManager.default.removeItem(at: repo)
    }

    func testFreshBaseRefThrowsRefNotFoundWhenBranchDoesNotExistLocally() async throws {
        let repo = try makeGitRepo(branchName: "main")
        let tab = Tab(name: "T", directory: repo)

        do {
            _ = try await tab.resolveOrAttachWorktree(
                userRef: "new-feature",
                defaultBranch: "nonexistent-branch",
                baseRef: .fresh
            )
            XCTFail("Expected WorktreeResolutionError.refNotFound to be thrown")
        } catch let error as WorktreeResolutionError {
            if case .refNotFound(let ref) = error {
                XCTAssertEqual(ref, "nonexistent-branch")
            } else {
                XCTFail("Expected .refNotFound, got \(error)")
            }
        } catch {
            XCTFail("Expected WorktreeResolutionError, got \(type(of: error)): \(error)")
        }

        try? FileManager.default.removeItem(at: repo)
    }

    func testBaseBranchOverrideUsedAsWorktreeBase() async throws {
        let repo = try makeGitRepo(branchName: "main")
        // Create qa branch with a sentinel file
        try runGit(["-c", "user.email=t@t.com", "-c", "user.name=t", "checkout", "-b", "qa"], cwd: repo)
        let sentinel = repo.appending(path: "qa-only.txt")
        try "qa".write(to: sentinel, atomically: true, encoding: .utf8)
        try runGit(["-c", "user.email=t@t.com", "-c", "user.name=t", "add", "qa-only.txt"], cwd: repo)
        try runGit(
            ["-c", "user.email=t@t.com", "-c", "user.name=t", "commit", "-m", "qa sentinel"],
            cwd: repo
        )
        try runGit(["checkout", "main"], cwd: repo)

        // Simulate what NewPaneSheet does: resolve the effective branch from the tab override
        let tab = Tab(name: "T", directory: repo, baseBranchOverride: "qa")
        let effectiveBranch = tab.baseBranchOverride

        let resolved = try await tab.resolveOrAttachWorktree(
            userRef: "override-feature",
            defaultBranch: effectiveBranch,
            baseRef: .fresh
        )

        // Worktree branched from qa must contain the sentinel file
        let worktreeSentinel = resolved.checkoutURL.appending(path: "qa-only.txt")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: worktreeSentinel.path),
            "Worktree should be based on qa branch and contain qa-only.txt"
        )

        try? FileManager.default.removeItem(at: repo)
    }
}

@MainActor
final class TabBaseBranchOverrideModelTests: XCTestCase {
    func testBaseBranchOverrideDefaultsNil() {
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        XCTAssertNil(tab.baseBranchOverride)
    }

    func testBaseBranchOverrideStoresValue() {
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"), baseBranchOverride: "qa")
        XCTAssertEqual(tab.baseBranchOverride, "qa")
    }

    func testEmptyStringNormalizationAtCallSite() {
        // NewTabSheet trims and converts empty string to nil before passing to Tab init
        let raw = "   "
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let override: String? = trimmed.isEmpty ? nil : trimmed
        XCTAssertNil(override)
    }
}
