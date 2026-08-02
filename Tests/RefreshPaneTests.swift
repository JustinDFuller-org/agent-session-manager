import XCTest

@testable import AgentSessionManager

final class RefreshPaneTests: XCTestCase {
    // MARK: - injectContinueFlagIntoArgs

    func testInjectContinueFlagIntoArgsAddsWhenMissing() {
        let result = Tab.injectContinueFlagIntoArgs(["--model", "opus"])
        XCTAssertEqual(result, ["--model", "opus", "--continue"])
    }

    func testInjectContinueFlagIntoArgsNoOpWhenPresent() {
        let result = Tab.injectContinueFlagIntoArgs(["--continue", "--model", "opus"])
        XCTAssertEqual(result, ["--continue", "--model", "opus"])
    }

    func testInjectContinueFlagIntoArgsEmpty() {
        let result = Tab.injectContinueFlagIntoArgs([])
        XCTAssertEqual(result, ["--continue"])
    }

    func testInjectContinueFlagIntoArgsPreservesExplicitResume() {
        for args in [
            ["--resume", "chat-id"],
            ["--resume=chat-id"],
            ["--continue", "--model", "opus"],
        ] {
            XCTAssertEqual(Tab.injectContinueFlagIntoArgs(args), args)
        }
    }

    // MARK: - buildClaudeCommand

    func testBuildClaudeCommandIncludesContinue() {
        let cmd = Tab.buildClaudeCommand(settingsPath: "/tmp/test.json", extraArgs: ["--model", "opus", "--continue"])
        XCTAssertTrue(cmd.contains("--continue"))
        XCTAssertTrue(cmd.contains("--settings"))
        XCTAssertTrue(cmd.contains("--model"))
        XCTAssertTrue(cmd.contains("opus"))
    }

    @MainActor
    func testQuickRefreshPreservesCursorPaneEnvironmentAndCommand() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = Pane(name: "cursor-pane", tab: tab, harness: .cursor)
        pane.extraArgs = ["--model", "test"]
        let controller = TerminalController()
        controller.pendingCommandArgs = ["agent", "--model", "test"]
        controller.pendingDirectory = "/tmp/repo"
        controller.pendingEnvironment = ["PATH=/usr/bin"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.refreshPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingCommandArgs, ["agent", "--model", "test"])
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
        controller.pendingCommandArgs = ["opencode", "--old-flag"]
        controller.pendingDirectory = "/tmp/repo"
        controller.pendingEnvironment = ["PATH=/usr/bin"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.refreshPane(pane)

        XCTAssertNotEqual(pane.opencodePort, 11111)
        XCTAssertNotNil(pane.opencodePort)
        let args = pane.terminalController?.pendingCommandArgs ?? []
        XCTAssertEqual(args.prefix(4), ["opencode", "--hostname", "127.0.0.1", "--mdns"])
        XCTAssertTrue(args.contains("--port"))
        XCTAssertTrue(args.contains(String(pane.opencodePort!)))
        XCTAssertTrue(args.contains("--verbose"))
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_OPENCODE_PORT=\(pane.opencodePort!)") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true") == true)
        XCTAssertFalse(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_DISABLE_PRUNE=true") == true)
    }

    @MainActor
    func testQuickRefreshReinjectsOpenCodeSessionIdWhenKnown() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = Pane(name: "opencode-pane", tab: tab, harness: .opencode)
        pane.opencodePort = 11111
        pane.opencodeSessionID = "ses_resume"
        pane.extraArgs = ["--verbose"]
        let controller = TerminalController()
        controller.pendingCommandArgs = ["opencode", "--old-flag"]
        controller.pendingDirectory = "/tmp/repo"
        controller.pendingEnvironment = ["PATH=/usr/bin"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.refreshPane(pane)

        XCTAssertNotEqual(pane.opencodePort, 11111)
        XCTAssertNotNil(pane.opencodePort)
        let args = pane.terminalController?.pendingCommandArgs ?? []
        XCTAssertTrue(args.contains("--port"))
        XCTAssertTrue(args.contains(String(pane.opencodePort!)))
        XCTAssertTrue(args.contains("--session"))
        XCTAssertTrue(args.contains("ses_resume"))
        XCTAssertTrue(args.contains("--verbose"))
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_DISABLE_PRUNE=true") == true)
    }

    @MainActor
    func testRefreshWithNewSettingsPreservesOpenCodeSessionFlag() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = Pane(name: "opencode-pane", tab: tab, harness: .opencode)
        pane.installTerminalController(TerminalController())
        tab.panes.append(pane)

        tab.refreshPane(pane, extraArgs: ["--session", "ses_resume", "--verbose"], harness: .opencode)

        let args = pane.terminalController?.pendingCommandArgs ?? []
        XCTAssertTrue(args.contains("--session"))
        XCTAssertTrue(args.contains("ses_resume"))
        XCTAssertTrue(args.contains("--verbose"))
        XCTAssertEqual(args.prefix(4), ["opencode", "--hostname", "127.0.0.1", "--mdns"])
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_DISABLE_PRUNE=true") == true)
    }

    @MainActor
    func testRefreshWithNewSettingsPreservesExtraArgsForClaude() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = Pane(name: "claude-pane", tab: tab, harness: .claude)
        pane.extraArgs = ["--model", "opus"]
        let controller = TerminalController()
        controller.pendingCommandArgs = ["claude", "--settings", "/tmp/old.json", "--model", "opus"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.refreshPane(pane, extraArgs: ["--model", "sonnet"], harness: .claude)

        let args = pane.terminalController?.pendingCommandArgs ?? []
        XCTAssertTrue(args.contains("--settings"))
        XCTAssertTrue(args.contains("--model"))
        XCTAssertTrue(args.contains("sonnet"))
    }
}
