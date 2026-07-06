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

    @MainActor
    func testQuickRefreshPreservesCursorPaneEnvironmentAndCommand() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = Pane(name: "cursor-pane", tab: tab, harness: .cursor)
        let controller = TerminalController()
        controller.pendingCommand = "agent --model test"
        controller.pendingDirectory = "/tmp/repo"
        controller.pendingEnvironment = ["PATH=/usr/bin"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.refreshPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingCommand, "agent --model test")
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)") == true)
    }

    @MainActor
    func testQuickRefreshRebuildsOpenCodeCommandWithFreshPort() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = Pane(name: "opencode-pane", tab: tab, harness: .opencode)
        pane.opencodePort = 11111
        pane.extraArgs = ["--verbose"]
        let controller = TerminalController()
        controller.pendingCommand = "opencode --old-flag"
        controller.pendingDirectory = "/tmp/repo"
        controller.pendingEnvironment = ["PATH=/usr/bin"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.refreshPane(pane)

        XCTAssertNotEqual(pane.opencodePort, 11111)
        XCTAssertNotNil(pane.opencodePort)
        let command = pane.terminalController?.pendingCommand ?? ""
        XCTAssertTrue(command.hasPrefix("opencode --hostname 127.0.0.1 --mdns=false"))
        XCTAssertTrue(command.contains(" --port \(pane.opencodePort!)"))
        XCTAssertTrue(command.hasSuffix(" --verbose"))
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_OPENCODE_PORT=\(pane.opencodePort!)") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true") == true)
    }
}
