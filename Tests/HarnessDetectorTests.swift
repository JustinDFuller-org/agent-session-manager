import XCTest

@testable import AgentSessionManager

final class HarnessDetectorTests: XCTestCase {
    func testDetectsInstalledToolsFromFakeRunner() async {
        let installed: Set<String> = ["claude", "codex"]
        let result = await HarnessDetector.detectInstalled(shell: "/bin/zsh") { _, command in
            installed.contains(command)
        }
        XCTAssertTrue(result.contains(.claude))
        XCTAssertTrue(result.contains(.codex))
        XCTAssertFalse(result.contains(.cursor))
        XCTAssertFalse(result.contains(.opencode))
    }

    func testReturnsEmptySetWhenNothingInstalled() async {
        let result = await HarnessDetector.detectInstalled(shell: "/bin/zsh") { _, _ in false }
        XCTAssertTrue(result.isEmpty)
    }

    func testDetectsAllTools() async {
        let result = await HarnessDetector.detectInstalled(shell: "/bin/zsh") { _, _ in true }
        for tool in Harness.allCases {
            XCTAssertTrue(result.contains(tool), "Expected \(tool) to be detected")
        }
    }

    func testCursorMapsToAgentBinary() async {
        // Cursor's commandDescription is "agent", not "cursor".
        let result = await HarnessDetector.detectInstalled(shell: "/bin/zsh") { _, command in
            command == "agent"
        }
        XCTAssertTrue(result.contains(.cursor))
        XCTAssertFalse(result.contains(.claude))
    }

    func testHarnessAllCasesExcludesShell() {
        // HarnessDetector only probes Harness.allCases which excludes .shell.
        XCTAssertFalse(Harness.allCases.contains(.shell))
    }
}
