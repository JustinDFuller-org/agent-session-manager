import XCTest

@testable import AgentSessionManager

@MainActor
final class PaneSetupStateTests: XCTestCase {
    func testPaneInitializesWithNilSetupState() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "test", tab: tab, cliType: .claude)
        XCTAssertNil(pane.setupState)
    }

    func testAddPaneWithLoadingStateReturnsLoadingPane() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = tab.addPaneWithLoadingState(name: "feature", cliType: .claude)
        guard case .loading = pane.setupState else {
            XCTFail("Expected .loading, got \(String(describing: pane.setupState))")
            return
        }
        XCTAssertNil(pane.terminalController)
    }

    func testAddPaneWithLoadingStateAppendsToTab() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        XCTAssertEqual(tab.panes.count, 0)
        tab.addPaneWithLoadingState(name: "feature", cliType: .claude)
        XCTAssertEqual(tab.panes.count, 1)
    }

    func testAddPaneWithLoadingStateSetsNameAndCLIType() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = tab.addPaneWithLoadingState(name: "my-branch", cliType: .codex, profileID: nil)
        XCTAssertEqual(pane.name, "my-branch")
        XCTAssertEqual(pane.cliType, .codex)
    }

    func testCompleteSetupClearsSetupState() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = tab.addPaneWithLoadingState(name: "feature", cliType: .claude)

        guard case .loading = pane.setupState else {
            XCTFail("Expected .loading before completeSetup")
            return
        }

        let resolved = ResolvedWorktree(
            paneTitle: "feature",
            processDirectory: URL(filePath: "/tmp/feature"),
            checkoutURL: URL(filePath: "/tmp/feature"),
            isExternalTakeover: false
        )
        tab.completeSetup(
            for: pane,
            resolved: resolved,
            managed: true,
            effectiveExtraArgs: [],
            extraEnvVars: [:],
            statusLineConfigOverride: nil
        )

        XCTAssertNil(pane.setupState)
    }

    func testCompleteSetupUpdatesPane() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = tab.addPaneWithLoadingState(name: "original-name", cliType: .claude)

        let resolved = ResolvedWorktree(
            paneTitle: "resolved-name",
            processDirectory: URL(filePath: "/tmp/resolved"),
            checkoutURL: URL(filePath: "/tmp/resolved"),
            isExternalTakeover: false
        )
        tab.completeSetup(
            for: pane,
            resolved: resolved,
            managed: true,
            effectiveExtraArgs: ["--flag"],
            extraEnvVars: [:],
            statusLineConfigOverride: nil
        )

        XCTAssertEqual(pane.name, "resolved-name")
        XCTAssertEqual(pane.worktreeDirectory, URL(filePath: "/tmp/resolved"))
        XCTAssertTrue(pane.worktreeIsManaged)
        XCTAssertEqual(pane.extraArgs, ["--flag"])
    }

    func testPaneSetupStateFailedStoresError() {
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = tab.addPaneWithLoadingState(name: "broken", cliType: .claude)
        pane.setupState = .failed(error: "git fetch failed")
        guard case .failed(let msg) = pane.setupState else {
            XCTFail("Expected .failed")
            return
        }
        XCTAssertEqual(msg, "git fetch failed")
    }
}
