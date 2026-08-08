import XCTest

@testable import AgentSessionManager

private final class StringBox: @unchecked Sendable {
    var value: String?
}

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

    func testDetectsOpenCodeBinary() async {
        let result = await HarnessDetector.detectInstalled(shell: "/bin/zsh") { _, command in
            command == "opencode"
        }
        XCTAssertTrue(result.contains(.opencode))
        XCTAssertFalse(result.contains(.claude))
        XCTAssertFalse(result.contains(.codex))
        XCTAssertFalse(result.contains(.cursor))
    }

    func testDetectsOhMyPiBinary() async {
        let result = await HarnessDetector.detectInstalled(shell: "/bin/zsh") { _, command in
            command == "omp"
        }
        XCTAssertTrue(result.contains(.omp))
        XCTAssertFalse(result.contains(.claude))
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

    func testIsInstalledTrueWhenRunnerFindsBinary() async {
        let installed = await HarnessDetector.isInstalled(harness: .opencode, shell: "/bin/zsh") { _, command in
            command == "opencode"
        }
        XCTAssertTrue(installed)
    }

    func testIsInstalledFalseWhenRunnerDoesNotFindBinary() async {
        let installed = await HarnessDetector.isInstalled(harness: .opencode, shell: "/bin/zsh") { _, _ in false }
        XCTAssertFalse(installed)
    }

    func testIsInstalledUsesCorrectCommandDescription() async {
        let checkedCommand = StringBox()
        _ = await HarnessDetector.isInstalled(harness: .cursor, shell: "/bin/zsh") { _, command in
            checkedCommand.value = command
            return false
        }
        XCTAssertEqual(checkedCommand.value, "agent")
    }
}
