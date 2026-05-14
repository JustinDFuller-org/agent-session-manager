import XCTest

@testable import AgentSessionManager

final class RefreshPaneTests: XCTestCase {

    // MARK: - injectContinueFlag

    func testInjectContinueFlagAddsWhenMissing() {
        let command = "claude --settings '/tmp/settings.json' --model opus"
        let result = Tab.injectContinueFlag(into: command)
        XCTAssertTrue(result.hasSuffix("--continue"))
        XCTAssertEqual(result, "claude --settings '/tmp/settings.json' --model opus --continue")
    }

    func testInjectContinueFlagNoOpWhenPresent() {
        let command = "claude --settings '/tmp/settings.json' --continue --model opus"
        let result = Tab.injectContinueFlag(into: command)
        XCTAssertEqual(result, command)
    }

    func testInjectContinueFlagEmptyCommand() {
        let result = Tab.injectContinueFlag(into: "")
        XCTAssertEqual(result, " --continue")
    }

    func testInjectContinueFlagSimpleCommand() {
        let result = Tab.injectContinueFlag(into: "claude")
        XCTAssertEqual(result, "claude --continue")
    }

    // MARK: - extractExtraArgs

    func testExtractExtraArgsFromClaudeCommand() {
        let command = "claude --settings '/tmp/agent-session-manager-settings-ABC.json' --model opus --verbose"
        let extra = Tab.extractExtraArgs(from: command)
        XCTAssertEqual(extra, " --model opus --verbose")
    }

    func testExtractExtraArgsNoExtraArgs() {
        let command = "claude --settings '/tmp/agent-session-manager-settings-ABC.json'"
        let extra = Tab.extractExtraArgs(from: command)
        XCTAssertEqual(extra, "")
    }

    func testExtractExtraArgsNoSettingsFlag() {
        let command = "codex --model opus"
        let extra = Tab.extractExtraArgs(from: command)
        XCTAssertEqual(extra, " --model opus")
    }

    func testExtractExtraArgsFromSingleWord() {
        let command = "claude"
        let extra = Tab.extractExtraArgs(from: command)
        XCTAssertEqual(extra, "")
    }

    // MARK: - injectContinueFlagIntoArgs

    func testInjectContinueFlagIntoArgsAddsWhenMissing() {
        let result = Tab.injectContinueFlagIntoArgs(" --model opus")
        XCTAssertEqual(result, " --model opus --continue")
    }

    func testInjectContinueFlagIntoArgsNoOpWhenPresent() {
        let result = Tab.injectContinueFlagIntoArgs(" --continue --model opus")
        XCTAssertEqual(result, " --continue --model opus")
    }

    func testInjectContinueFlagIntoArgsEmpty() {
        let result = Tab.injectContinueFlagIntoArgs("")
        XCTAssertEqual(result, " --continue")
    }

    // MARK: - buildClaudeCommand

    func testBuildClaudeCommandIncludesContinue() {
        let cmd = Tab.buildClaudeCommand(settingsPath: "/tmp/test.json", extraArgs: " --model opus --continue")
        XCTAssertTrue(cmd.contains("--continue"))
        XCTAssertTrue(cmd.contains("--settings"))
        XCTAssertTrue(cmd.contains("--model opus"))
    }
}
