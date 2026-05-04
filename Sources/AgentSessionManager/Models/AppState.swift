import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var tabs: [Tab] = []
    var activeTabID: UUID?
    var activePaneID: UUID?

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }

    var activePane: Pane? {
        activeTab?.panes.first { $0.id == activePaneID }
    }

    func addTab(name: String, directory: URL) {
        let tab = Tab(name: name, directory: directory)
        tabs.append(tab)
        activeTabID = tab.id
    }

    func switchToTab(id: UUID) {
        activeTab?.lastActivePaneID = activePaneID
        activeTabID = id
        let saved = activeTab?.lastActivePaneID
        activePaneID = activeTab?.panes.first(where: { $0.id == saved })?.id ?? activeTab?.panes.first?.id
    }

    func setActivePane(id: UUID?) {
        activeTab?.lastActivePaneID = id
        activePaneID = id
    }

    func isWorktreeDuplicate(directory: URL, name: String) -> Bool {
        tabs.contains { $0.directory == directory && $0.hasPaneNamed(name) }
    }

    func closeTab(_ tab: Tab) {
        tab.panes.forEach { $0.terminalController?.terminate() }
        tabs.removeAll { $0.id == tab.id }
        if activeTabID == tab.id {
            activeTabID = tabs.last?.id
        }
    }
}
