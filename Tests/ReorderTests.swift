import XCTest
@testable import AgentSessionManager

@MainActor
final class ReorderTests: XCTestCase {
    private func makeState(tabCount: Int) -> (AppState, [Tab]) {
        let state = AppState()
        let url = URL(filePath: "/tmp")
        let tabs = (1...tabCount).map { i in
            let tab = Tab(name: "tab\(i)", directory: url)
            state.tabs.append(tab)
            return tab
        }
        return (state, tabs)
    }

    private func makePanes(tab: Tab, count: Int) -> [Pane] {
        let panes = (1...count).map { i in Pane(name: "pane\(i)", tab: tab) }
        tab.panes = panes
        return panes
    }

    func testMoveTabForward() {
        let (state, tabs) = makeState(tabCount: 3)
        state.moveTab(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(state.tabs.map(\.id), [tabs[1].id, tabs[0].id, tabs[2].id])
    }

    func testMoveTabBackward() {
        let (state, tabs) = makeState(tabCount: 3)
        state.moveTab(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(state.tabs.map(\.id), [tabs[2].id, tabs[0].id, tabs[1].id])
    }

    func testMoveTabToEnd() {
        let (state, tabs) = makeState(tabCount: 3)
        state.moveTab(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(state.tabs.map(\.id), [tabs[1].id, tabs[2].id, tabs[0].id])
    }

    func testMovePaneForward() {
        let (_, tabs) = makeState(tabCount: 1)
        let panes = makePanes(tab: tabs[0], count: 3)
        tabs[0].movePane(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(tabs[0].panes.map(\.id), [panes[1].id, panes[0].id, panes[2].id])
    }

    func testMovePaneBackward() {
        let (_, tabs) = makeState(tabCount: 1)
        let panes = makePanes(tab: tabs[0], count: 3)
        tabs[0].movePane(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(tabs[0].panes.map(\.id), [panes[2].id, panes[0].id, panes[1].id])
    }
}
