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

    func testOhMyPiCompatibilityAcceptsPinnedVersion() async {
        let result = await HarnessDetector.checkOhMyPiCompatibility(shell: "/bin/zsh") { _, _ in
            .init(status: 0, stdout: "omp v17.2.11\n", stderr: "")
        }

        XCTAssertEqual(result, .supported(.init(major: 17, minor: 2, patch: 11)))
    }

    func testOhMyPiCompatibilityAcceptsLaterSeventeenVersion() async {
        let result = await HarnessDetector.checkOhMyPiCompatibility(shell: "/bin/zsh") { _, _ in
            .init(status: 0, stdout: "omp v17.9.0\n", stderr: "")
        }

        XCTAssertEqual(result, .supported(.init(major: 17, minor: 9, patch: 0)))
    }

    func testOhMyPiCompatibilityRejectsEarlierVersion() async {
        let result = await HarnessDetector.checkOhMyPiCompatibility(shell: "/bin/zsh") { _, _ in
            .init(status: 0, stdout: "omp v17.2.10\n", stderr: "")
        }

        XCTAssertEqual(result, .unsupported(.init(major: 17, minor: 2, patch: 10)))
    }

    func testOhMyPiCompatibilityRejectsNextMajorVersion() async {
        let result = await HarnessDetector.checkOhMyPiCompatibility(shell: "/bin/zsh") { _, _ in
            .init(status: 0, stdout: "omp v18.0.0\n", stderr: "")
        }

        XCTAssertEqual(result, .unsupported(.init(major: 18, minor: 0, patch: 0)))
    }

    func testOhMyPiCompatibilityRejectsUnparseableOutput() async {
        let result = await HarnessDetector.checkOhMyPiCompatibility(shell: "/bin/zsh") { _, _ in
            .init(status: 0, stdout: "Oh My Pi v17.2.11\n", stderr: "")
        }

        XCTAssertEqual(result, .unparseable)
    }

    func testOhMyPiCompatibilityRecognizesMissingCommand() async {
        let result = await HarnessDetector.checkOhMyPiCompatibility(shell: "/bin/zsh") { _, _ in
            .init(status: 127, stdout: "", stderr: "omp: command not found")
        }

        XCTAssertEqual(result, .missing)
    }

    func testOhMyPiCompatibilityRecognizesLaunchFailure() async {
        let result = await HarnessDetector.checkOhMyPiCompatibility(shell: "/bin/zsh") { _, _ in
            .init(status: 1, stdout: "", stderr: "failed")
        }

        XCTAssertEqual(result, .launchFailed)
    }
}
