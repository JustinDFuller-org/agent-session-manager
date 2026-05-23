import XCTest

@testable import AgentSessionManager

@MainActor
final class PlainTerminalAccessTests: XCTestCase {
    // MARK: - CLIType.shell

    func testShellCLITypeDisplayName() {
        XCTAssertEqual(CLIType.shell.displayName, "Shell")
    }

    func testShellCLITypeCommandDescription() {
        XCTAssertEqual(CLIType.shell.cliCommandDescription, "$SHELL")
    }

    func testShellNotInAllCases() {
        XCTAssertFalse(CLIType.allCases.contains(.shell))
    }

    func testAllCasesContainsUserFacingTools() {
        XCTAssertTrue(CLIType.allCases.contains(.claude))
        XCTAssertTrue(CLIType.allCases.contains(.codex))
        XCTAssertTrue(CLIType.allCases.contains(.cursor))
        XCTAssertTrue(CLIType.allCases.contains(.opencode))
    }

    func testShellCLITypeCodableRoundTrip() throws {
        let encoded = try JSONEncoder().encode(CLIType.shell)
        let decoded = try JSONDecoder().decode(CLIType.self, from: encoded)
        XCTAssertEqual(decoded, .shell)
    }

    // MARK: - Pane.restartToken

    func testRestartTokenIsInitializedToNonNilUUID() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let token = pane.restartToken
        XCTAssertNotNil(token)
    }

    // MARK: - Tab.restartPane

    func testRestartPanePreservesCommand() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude --settings /tmp/test.json"
        controller.pendingDirectory = "/tmp/repo"
        controller.pendingEnvironment = ["PATH=/usr/bin"]
        pane.terminalController = controller
        tab.panes.append(pane)

        tab.restartPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingCommand, "claude --settings /tmp/test.json")
    }

    func testRestartPanePreservesDirectory() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        controller.pendingDirectory = "/tmp/my-repo"
        pane.terminalController = controller
        tab.panes.append(pane)

        tab.restartPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingDirectory, "/tmp/my-repo")
    }

    func testRestartPanePreservesEnvironment() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        controller.pendingEnvironment = ["FOO=bar", "PATH=/usr/bin"]
        pane.terminalController = controller
        tab.panes.append(pane)

        tab.restartPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingEnvironment, ["FOO=bar", "PATH=/usr/bin"])
    }

    func testRestartTokenChangesOnRestart() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        pane.terminalController = controller
        tab.panes.append(pane)
        let originalToken = pane.restartToken

        tab.restartPane(pane)

        XCTAssertNotEqual(pane.restartToken, originalToken)
    }

    func testRestartPaneCreatesNewController() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let original = TerminalController()
        original.pendingCommand = "claude"
        pane.terminalController = original
        tab.panes.append(pane)

        tab.restartPane(pane)

        XCTAssertFalse(pane.terminalController === original)
    }

    // MARK: - Tab.openShellInPane

    func testOpenShellInPaneClearsCommand() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude --settings /tmp/test.json"
        controller.pendingDirectory = "/tmp/repo"
        pane.terminalController = controller
        tab.panes.append(pane)

        tab.openShellInPane(pane)

        XCTAssertNil(pane.terminalController?.pendingCommand)
    }

    func testOpenShellInPanePreservesDirectory() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        controller.pendingDirectory = "/tmp/my-repo"
        pane.terminalController = controller
        tab.panes.append(pane)

        tab.openShellInPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingDirectory, "/tmp/my-repo")
    }

    func testOpenShellInPaneSetsShellCLIType() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        pane.terminalController = controller
        tab.panes.append(pane)

        tab.openShellInPane(pane)

        XCTAssertEqual(pane.cliType, .shell)
    }

    func testOpenShellInPaneChangesRestartToken() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        pane.terminalController = controller
        tab.panes.append(pane)
        let originalToken = pane.restartToken

        tab.openShellInPane(pane)

        XCTAssertNotEqual(pane.restartToken, originalToken)
    }

    // MARK: - Tab.openShellPane

    func testOpenShellPaneAddsPaneToTab() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let existingPane = Pane(name: "claude", tab: tab, cliType: .claude)
        tab.panes.append(existingPane)
        let initialCount = tab.panes.count

        tab.openShellPane(activePane: existingPane)

        XCTAssertEqual(tab.panes.count, initialCount + 1)
    }

    func testOpenShellPaneAddedPaneHasShellCLIType() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        tab.openShellPane(activePane: nil)
        XCTAssertEqual(tab.panes.last?.cliType, .shell)
    }

    // MARK: - ExitBehavior

    func testExitBehaviorDisplayNames() {
        XCTAssertEqual(ExitBehavior.prompt.displayName, "Show Prompt")
        XCTAssertEqual(ExitBehavior.autoShell.displayName, "Open Shell")
        XCTAssertEqual(ExitBehavior.close.displayName, "Close Pane")
    }

    func testExitBehaviorCodableRoundTrip() throws {
        for behavior in ExitBehavior.allCases {
            let encoded = try JSONEncoder().encode(behavior)
            let decoded = try JSONDecoder().decode(ExitBehavior.self, from: encoded)
            XCTAssertEqual(decoded, behavior)
        }
    }

    func testExitBehaviorDefaultIsPrompt() {
        let settings = AppSettings()
        XCTAssertEqual(settings.exitBehavior, .prompt)
    }

    // MARK: - Session persistence excludes shell panes

    func testShellPanesExcludedFromSessionPersistence() {
        let appState = AppState()
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let claudePane = Pane(
            name: "claude-session", tab: tab, cliType: .claude,
            worktreeDirectory: URL(filePath: "/tmp"))
        let shellPane = Pane(name: "shell", tab: tab, cliType: .shell)
        tab.panes.append(claudePane)
        tab.panes.append(shellPane)
        appState.tabs.append(tab)

        let session = SessionPersistence.makePersistedSession(appState: appState)

        let savedPaneTypes = session.tabs.first?.panes.map(\.cliType) ?? []
        XCTAssertFalse(savedPaneTypes.contains(.shell), "Shell panes should not be saved")
        XCTAssertTrue(savedPaneTypes.contains(.claude), "Claude panes should be saved")
    }
}
