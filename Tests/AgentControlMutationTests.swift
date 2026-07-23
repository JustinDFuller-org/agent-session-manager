import Foundation
import MCP
import XCTest

@testable import AgentSessionManager

@MainActor
final class AgentControlMutationTests: XCTestCase {
    func testPaneScopeCannotMutateAnotherPaneOrCreatePane() async throws {
        let fixture = makeFixture()

        do {
            _ = try await fixture.router.callTool(
                name: "panes.focus",
                arguments: ["paneID": .string(fixture.otherPane.id.uuidString)],
                source: fixture.paneSource)
            XCTFail("Pane scope must not focus another pane")
        } catch let error as MCPError {
            XCTAssertTrue(String(describing: error).contains("scope"))
        }

        do {
            _ = try await fixture.router.callTool(
                name: "panes.create",
                arguments: [
                    "tabID": .string(fixture.tab.id.uuidString),
                    "worktreeRef": .string("new-pane"),
                    "harness": .string("claude"),
                ],
                source: fixture.paneSource)
            XCTFail("Pane scope must not create a pane")
        } catch let error as MCPError {
            XCTAssertTrue(String(describing: error).contains("scope"))
        }
    }

    func testTabScopeCanFocusAndReorderPanesOnlyInItsTab() async throws {
        let fixture = makeFixture()

        let focus = try await fixture.router.callTool(
            name: "panes.focus",
            arguments: ["paneID": .string(fixture.otherPane.id.uuidString)],
            source: fixture.tabSource)
        XCTAssertNotEqual(focus.isError, true)
        XCTAssertEqual(fixture.state.activePaneID, fixture.otherPane.id)
        XCTAssertEqual(fixture.tab.focusedPaneID, fixture.otherPane.id)

        let reorder = try await fixture.router.callTool(
            name: "panes.reorder",
            arguments: [
                "paneID": .string(fixture.firstPane.id.uuidString),
                "destinationIndex": .int(2),
            ],
            source: fixture.tabSource)
        XCTAssertNotEqual(reorder.isError, true)
        XCTAssertEqual(fixture.tab.panes.map(\.id), [fixture.otherPane.id, fixture.firstPane.id])

        do {
            _ = try await fixture.router.callTool(
                name: "panes.focus",
                arguments: ["paneID": .string(fixture.secondTabPane.id.uuidString)],
                source: fixture.tabSource)
            XCTFail("Tab scope must not reach another tab")
        } catch let error as MCPError {
            XCTAssertTrue(String(describing: error).contains("scope"))
        }
    }

    func testGlobalScopeCanFocusAndReorderTabs() async throws {
        let fixture = makeFixture()

        let focus = try await fixture.router.callTool(
            name: "tabs.focus",
            arguments: ["tabID": .string(fixture.secondTab.id.uuidString)],
            source: fixture.globalSource)
        XCTAssertNotEqual(focus.isError, true)
        XCTAssertEqual(fixture.state.activeTabID, fixture.secondTab.id)

        let reorder = try await fixture.router.callTool(
            name: "tabs.reorder",
            arguments: [
                "tabID": .string(fixture.secondTab.id.uuidString),
                "destinationIndex": .int(0),
            ],
            source: fixture.globalSource)
        XCTAssertNotEqual(reorder.isError, true)
        XCTAssertEqual(fixture.state.tabs.map(\.id), [fixture.secondTab.id, fixture.tab.id])
    }

    func testGlobalScopeCanCreateTabFromAnExistingDirectory() async throws {
        let fixture = makeFixture()
        let directory = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)

        let response = try await fixture.router.callTool(
            name: "tabs.create",
            arguments: [
                "name": .string("Created Tab"),
                "directory": .string(directory.path),
            ],
            source: fixture.globalSource)

        XCTAssertNotEqual(response.isError, true)
        XCTAssertEqual(fixture.state.tabs.count, 3)
        XCTAssertEqual(fixture.state.tabs.last?.name, "Created Tab")
        XCTAssertEqual(fixture.state.activeTabID, fixture.state.tabs.last?.id)
    }

    func testCleanupPolicyRequiresChoiceAndReportsPartialFailures() async throws {
        let state = AppState()
        let settings = AppSettings()
        let tab = Tab(name: "Managed Tab", directory: URL(filePath: NSTemporaryDirectory()))
        let pane = tab.addPane(
            name: "Managed Pane", harness: .claude,
            worktreeDirectory: URL(filePath: NSTemporaryDirectory()), worktreeIsManaged: true,
            appSettings: settings)
        state.tabs = [tab]
        state.activeTabID = tab.id
        state.activePaneID = pane.id
        let router = AgentControlMutationRouter(appState: state, appSettings: settings)
        let source = AgentControlSource(
            paneID: pane.id, paneName: pane.name, tabID: tab.id, tabName: tab.name, scope: .global)

        do {
            _ = try await router.callTool(
                name: "tabs.delete", arguments: ["tabID": .string(tab.id.uuidString)], source: source)
            XCTFail("Ask cleanup policy must require an explicit choice")
        } catch let error as MCPError {
            XCTAssertTrue(String(describing: error).contains("cleanup"))
        }
        XCTAssertEqual(state.tabs.count, 1)

        let response = try await router.callTool(
            name: "tabs.delete",
            arguments: [
                "tabID": .string(tab.id.uuidString),
                "cleanup": .string("delete"),
            ],
            source: source)
        XCTAssertNotEqual(response.isError, true)
        XCTAssertTrue(toolText(response.content)?.contains("partial_failure") == true)
        XCTAssertTrue(toolText(response.content)?.contains("failed") == true)
        XCTAssertTrue(state.tabs.isEmpty)
    }

    func testMutationTelemetryContainsScopeAndIDsWithoutPayload() async throws {
        let fixture = makeFixture()
        TracingService.shared.enableTestCapture()
        defer { TracingService.shared.resetForTesting() }

        _ = try await fixture.router.callTool(
            name: "panes.focus",
            arguments: ["paneID": .string(fixture.otherPane.id.uuidString)],
            source: fixture.tabSource)

        let event = try XCTUnwrap(
            TracingService.shared.recordedEventsForTesting.last { $0.name == "agent_control.mutation" })
        XCTAssertEqual(event.attributes["tool"], "panes.focus")
        XCTAssertEqual(event.attributes["scope"], "tab")
        XCTAssertEqual(event.attributes["target.pane.id"], fixture.otherPane.id.uuidString)
        XCTAssertNil(event.attributes["payload"])
        XCTAssertNil(event.attributes["token"])
    }

    private struct Fixture {
        let state: AppState
        let router: AgentControlMutationRouter
        let tab: Tab
        let firstPane: Pane
        let otherPane: Pane
        let secondTab: Tab
        let secondTabPane: Pane
        let paneSource: AgentControlSource
        let tabSource: AgentControlSource
        let globalSource: AgentControlSource
    }

    private func makeFixture() -> Fixture {
        let state = AppState()
        let settings = AppSettings()
        let tab = Tab(name: "First Tab", directory: URL(filePath: NSTemporaryDirectory()))
        let firstPane = tab.addPane(
            name: "First Pane", harness: .claude,
            worktreeDirectory: URL(filePath: "/tmp/first-worktree"), appSettings: settings)
        let otherPane = tab.addPane(
            name: "Other Pane", harness: .codex,
            worktreeDirectory: URL(filePath: "/tmp/other-worktree"), appSettings: settings)
        let secondTab = Tab(name: "Second Tab", directory: URL(filePath: NSTemporaryDirectory()))
        let secondTabPane = secondTab.addPane(
            name: "Second Tab Pane", harness: .cursor,
            worktreeDirectory: URL(filePath: "/tmp/second-tab-worktree"), appSettings: settings)
        state.tabs = [tab, secondTab]
        state.activeTabID = tab.id
        state.activePaneID = firstPane.id

        let router = AgentControlMutationRouter(appState: state, appSettings: settings)
        let paneSource = AgentControlSource(
            paneID: firstPane.id, paneName: firstPane.name, tabID: tab.id, tabName: tab.name, scope: .pane)
        let tabSource = AgentControlSource(
            paneID: firstPane.id, paneName: firstPane.name, tabID: tab.id, tabName: tab.name, scope: .tab)
        let globalSource = AgentControlSource(
            paneID: firstPane.id, paneName: firstPane.name, tabID: tab.id, tabName: tab.name, scope: .global)
        return Fixture(
            state: state, router: router, tab: tab, firstPane: firstPane, otherPane: otherPane,
            secondTab: secondTab, secondTabPane: secondTabPane, paneSource: paneSource,
            tabSource: tabSource, globalSource: globalSource)
    }

    private func toolText(_ content: [Tool.Content]) -> String? {
        guard case .text(let text, _, _) = content.first else { return nil }
        return text
    }
}
