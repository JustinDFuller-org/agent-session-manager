import XCTest

@testable import AgentSessionManager

@MainActor
final class ShellResolverTests: XCTestCase {
    func testDetectedLoginShellReturnsProcessInfoShell() {
        let shell = ShellResolver.detectedLoginShell()
        XCTAssertFalse(shell.isEmpty)
        XCTAssertTrue(shell.hasPrefix("/"), "Expected absolute path, got: \(shell)")
    }

    func testResolvedPrefersPreferredShell() {
        let settings = AppSettings()
        settings.preferredShell = "/bin/bash"
        XCTAssertEqual(ShellResolver.resolved(settings), "/bin/bash")
    }

    func testResolvedFallsBackToDetectedWhenEmpty() {
        let settings = AppSettings()
        settings.preferredShell = ""
        let resolved = ShellResolver.resolved(settings)
        XCTAssertEqual(resolved, ShellResolver.detectedLoginShell())
    }

    func testResolvedTrimsWhitespace() {
        let settings = AppSettings()
        settings.preferredShell = "  /bin/zsh  "
        XCTAssertEqual(ShellResolver.resolved(settings), "/bin/zsh")
    }

    func testResolvedFallsBackWhenOnlyWhitespace() {
        let settings = AppSettings()
        settings.preferredShell = "   "
        XCTAssertEqual(ShellResolver.resolved(settings), ShellResolver.detectedLoginShell())
    }

    func testCommonShellsAreAbsolutePaths() {
        for shell in ShellResolver.commonShells {
            XCTAssertTrue(shell.hasPrefix("/"), "Expected absolute path: \(shell)")
        }
    }

    func testCommonShellsOnlyContainExistingFiles() {
        for shell in ShellResolver.commonShells {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: shell),
                "Shell reported as common but not found: \(shell)"
            )
        }
    }
}
