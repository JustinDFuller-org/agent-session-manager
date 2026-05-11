import Foundation
import XCTest

/// Mirrors `NSTemporaryDirectory()/UITestWorkspace` used by `NewTabSheet` in UITesting mode.
enum GitUITestWorkspace {
    static var directoryURL: URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "UITestWorkspace", directoryHint: .isDirectory)
    }

    /// Wipes prior content, initializes a deterministic Git repo (`ui-root`).
    static func prepareCleanRepo() {
        let url = directoryURL
        try? FileManager.default.removeItem(at: url)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            XCTFail("create UITestWorkspace: \(error)")
            return
        }
        runGitOrFail(["init"], cwd: url)
        runGitOrFail(
            ["-c", "user.email=uitest@example.com", "-c", "user.name=uitest", "commit", "--allow-empty", "-m", "init"],
            cwd: url
        )
        runGitOrFail(["branch", "-M", "ui-root"], cwd: url)
    }

    static func addLooseBranch(named branch: String, file: StaticString = #file, line: UInt = #line) {
        runGitOrFail(["branch", branch, "HEAD"], cwd: directoryURL, file: file, line: line)
    }

    /// Adds a linked secondary worktree under `.agent-session-manager/worktrees/<folder>/`.
    static func addManagedSecondaryWorktree(
        folder: String,
        newTrackingBranch: String,
        baseBranch: String = "ui-root",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let rel = ".agent-session-manager/worktrees/\(folder)"
        runGitOrFail(
            ["worktree", "add", rel, "-b", newTrackingBranch, baseBranch], cwd: directoryURL, file: file, line: line)
    }

    private static func runGitOrFail(_ args: [String], cwd: URL, file: StaticString = #file, line: UInt = #line) {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = cwd

        let errPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            XCTFail("git launch failed \(args.joined(separator: " ")): \(error)", file: file, line: line)
            return
        }
        process.waitUntilExit()

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8) ?? ""

        XCTAssertEqual(
            process.terminationStatus, 0, "git \(args.joined(separator: " ")) failed: \(errText)", file: file,
            line: line)
    }
}
