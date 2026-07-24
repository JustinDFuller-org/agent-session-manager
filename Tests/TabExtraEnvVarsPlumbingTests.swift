import XCTest

@testable import AgentSessionManager

@MainActor
final class TabExtraEnvVarsPlumbingTests: XCTestCase {
    func testAddPaneInjectsExtraEnvVarsForCodex() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = tab.addPane(
            name: "codex-pane",
            harness: .codex,
            extraEnvVars: ["CUSTOM_KEY": "custom-value"]
        )

        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("CUSTOM_KEY=custom-value") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)") == true)
    }

    func testAddPaneInjectsExtraEnvVarsForCursor() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = tab.addPane(
            name: "cursor-pane",
            harness: .cursor,
            extraEnvVars: ["CUSTOM_KEY": "custom-value"]
        )

        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("CUSTOM_KEY=custom-value") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains(where: { $0.hasPrefix("AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR=") }) == true)
    }

    func testAddPaneInjectsExtraEnvVarsForOpenCode() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = tab.addPane(
            name: "opencode-pane",
            harness: .opencode,
            extraEnvVars: ["CUSTOM_KEY": "custom-value"]
        )

        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("CUSTOM_KEY=custom-value") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true") == true)
        XCTAssertNotNil(pane.opencodePort)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_OPENCODE_PORT=\(pane.opencodePort!)") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .first { $0.hasPrefix("OPENCODE_CONFIG_CONTENT=") } != nil,
            "Expected OPENCODE_CONFIG_CONTENT to be injected")
    }

    func testAddPaneInjectsExtraEnvVarsForClaude() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = tab.addPane(
            name: "claude-pane",
            harness: .claude,
            extraEnvVars: ["CUSTOM_KEY": "custom-value"]
        )

        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("CUSTOM_KEY=custom-value") == true)
    }

    func testRefreshPaneInjectsExtraEnvVarsForOpenCode() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = Pane(name: "opencode-pane", tab: tab, harness: .opencode)
        let controller = TerminalController()
        controller.pendingCommandArgs = ["opencode"]
        controller.pendingDirectory = "/tmp/repo"
        controller.pendingEnvironment = ["PATH=/usr/bin"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        tab.refreshPane(
            pane,
            extraArgs: [],
            harness: .opencode,
            extraEnvVars: ["OPENCODE_CLIENT": "agent-session-manager"]
        )

        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_CLIENT=agent-session-manager") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true") == true)
        XCTAssertNotNil(pane.opencodePort)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_OPENCODE_PORT=\(pane.opencodePort!)") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .first { $0.hasPrefix("OPENCODE_CONFIG_CONTENT=") } != nil,
            "Expected OPENCODE_CONFIG_CONTENT to be injected")
    }

    func testCompleteSetupInjectsExtraEnvVarsForOpenCode() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = tab.addPaneWithLoadingState(name: "opencode-pane", harness: .opencode)

        let resolved = ResolvedWorktree(
            paneTitle: "opencode-pane",
            processDirectory: URL(filePath: "/tmp/repo/opencode-pane"),
            checkoutURL: URL(filePath: "/tmp/repo/opencode-pane"),
            isExternalTakeover: false
        )
        tab.completeSetup(
            for: pane,
            resolved: resolved,
            managed: true,
            effectiveExtraArgs: [],
            extraEnvVars: ["OPENCODE_DISABLE_DEFAULT_PLUGINS": "true"],
            statusLineConfigOverride: nil
        )

        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_DISABLE_DEFAULT_PLUGINS=true") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true") == true)
        XCTAssertNotNil(pane.opencodePort)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .contains("AGENT_SESSION_MANAGER_OPENCODE_PORT=\(pane.opencodePort!)") == true)
        XCTAssertTrue(
            pane.terminalController?.pendingEnvironment?
                .first { $0.hasPrefix("OPENCODE_CONFIG_CONTENT=") } != nil,
            "Expected OPENCODE_CONFIG_CONTENT to be injected")
    }

    func testCompleteSetupInjectsExtraEnvVarsForCodexAndCursor() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))

        for harness in [Harness.codex, .cursor] {
            let pane = tab.addPaneWithLoadingState(name: "\(harness)-pane", harness: harness)
            let resolved = ResolvedWorktree(
                paneTitle: "\(harness)-pane",
                processDirectory: URL(filePath: "/tmp/repo/\(harness)-pane"),
                checkoutURL: URL(filePath: "/tmp/repo/\(harness)-pane"),
                isExternalTakeover: false
            )
            tab.completeSetup(
                for: pane,
                resolved: resolved,
                managed: true,
                effectiveExtraArgs: [],
                extraEnvVars: ["SHARED_KEY": "shared-value"],
                statusLineConfigOverride: nil
            )

            XCTAssertTrue(
                pane.terminalController?.pendingEnvironment?
                    .contains("SHARED_KEY=shared-value") == true,
                "Expected SHARED_KEY for \(harness)")
        }
    }
}
