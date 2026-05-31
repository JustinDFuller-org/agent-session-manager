import XCTest

@testable import AgentSessionManager

@MainActor
final class PlainTerminalAccessTests: XCTestCase {
    // MARK: - Harness.shell

    func testShellHarnessDisplayName() {
        XCTAssertEqual(Harness.shell.displayName, "Shell")
    }

    func testShellHarnessCommandDescription() {
        XCTAssertEqual(Harness.shell.commandDescription, "$SHELL")
    }

    func testShellNotInAllCases() {
        XCTAssertFalse(Harness.allCases.contains(.shell))
    }

    func testAllCasesContainsUserFacingTools() {
        XCTAssertTrue(Harness.allCases.contains(.claude))
        XCTAssertTrue(Harness.allCases.contains(.codex))
        XCTAssertTrue(Harness.allCases.contains(.cursor))
    }

    func testShellHarnessCodableRoundTrip() throws {
        let encoded = try JSONEncoder().encode(Harness.shell)
        let decoded = try JSONDecoder().decode(Harness.self, from: encoded)
        XCTAssertEqual(decoded, .shell)
    }

    // MARK: - Pane.restartToken

    func testRestartTokenIsInitializedToNonNilUUID() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let token = pane.restartToken
        XCTAssertNotNil(token)
    }

    // MARK: - Tab.restartPane

    func testRestartPanePreservesCommand() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude --settings /tmp/test.json"
        controller.pendingDirectory = "/tmp/repo"
        controller.pendingEnvironment = ["PATH=/usr/bin"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.restartPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingCommand, "claude --settings /tmp/test.json")
    }

    func testRestartPanePreservesDirectory() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        controller.pendingDirectory = "/tmp/my-repo"
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.restartPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingDirectory, "/tmp/my-repo")
    }

    func testRestartPanePreservesEnvironment() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        controller.pendingEnvironment = ["FOO=bar", "PATH=/usr/bin"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.restartPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingEnvironment, ["FOO=bar", "PATH=/usr/bin"])
    }

    func testRestartTokenChangesOnRestart() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        pane.installTerminalController(controller)
        tab.panes.append(pane)
        let originalToken = pane.restartToken

        tab.restartPane(pane)

        XCTAssertNotEqual(pane.restartToken, originalToken)
    }

    func testRestartPaneCreatesNewController() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let original = TerminalController()
        original.pendingCommand = "claude"
        pane.installTerminalController(original)
        tab.panes.append(pane)

        tab.restartPane(pane)

        XCTAssertFalse(pane.terminalController === original)
    }

    // MARK: - Tab.openShellInPane

    func testOpenShellInPaneClearsCommand() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude --settings /tmp/test.json"
        controller.pendingDirectory = "/tmp/repo"
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.openShellInPane(pane)

        XCTAssertNil(pane.terminalController?.pendingCommand)
    }

    func testOpenShellInPanePreservesDirectory() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        controller.pendingDirectory = "/tmp/my-repo"
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.openShellInPane(pane)

        XCTAssertEqual(pane.terminalController?.pendingDirectory, "/tmp/my-repo")
    }

    func testOpenShellInPaneSetsShellHarness() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.openShellInPane(pane)

        XCTAssertEqual(pane.harness, .shell)
    }

    func testOpenShellInPaneChangesRestartToken() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, harness: .claude)
        let controller = TerminalController()
        controller.pendingCommand = "claude"
        pane.installTerminalController(controller)
        tab.panes.append(pane)
        let originalToken = pane.restartToken

        tab.openShellInPane(pane)

        XCTAssertNotEqual(pane.restartToken, originalToken)
    }

    // MARK: - Tab.openShellPane

    func testOpenShellPaneAddsPaneToTab() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let existingPane = Pane(name: "claude", tab: tab, harness: .claude)
        tab.panes.append(existingPane)
        let initialCount = tab.panes.count

        tab.openShellPane(activePane: existingPane)

        XCTAssertEqual(tab.panes.count, initialCount + 1)
    }

    func testOpenShellPaneAddedPaneHasShellHarness() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        tab.openShellPane(activePane: nil)
        XCTAssertEqual(tab.panes.last?.harness, .shell)
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
            name: "claude-session", tab: tab, harness: .claude,
            worktreeDirectory: URL(filePath: "/tmp"))
        let shellPane = Pane(name: "shell", tab: tab, harness: .shell)
        tab.panes.append(claudePane)
        tab.panes.append(shellPane)
        appState.tabs.append(tab)

        let session = SessionPersistence.makePersistedSession(appState: appState)

        let savedPaneTypes = session.tabs.first?.panes.map(\.harness) ?? []
        XCTAssertFalse(savedPaneTypes.contains(.shell), "Shell panes should not be saved")
        XCTAssertTrue(savedPaneTypes.contains(.claude), "Claude panes should be saved")
    }
}
