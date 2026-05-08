import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var tabs: [Tab] = []
    var activeTabID: UUID?
    var activePaneID: UUID?
    var notifications: [PaneNotification] = []

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
        if let id { clearNotification(paneID: id) }
    }

    func isWorktreeDuplicate(directory: URL, name: String) -> Bool {
        tabs.contains { $0.directory == directory && $0.hasPaneNamed(name) }
    }

    /// True if a pane in that tab already uses this checkout directory.
    func isCheckoutInUse(directory: URL, checkout: URL) -> Bool {
        let normalized = checkout.standardizedFileURL
        return tabs.contains { tab in
            guard tab.directory == directory else { return false }
            return tab.panes.contains { pane in
                return pane.worktreePath?.standardizedFileURL == normalized
            }
        }
    }

    func closeTab(_ tab: Tab) {
        tab.panes.forEach {
            DebugLogger.shared.removeTracedPane($0.id)
            $0.terminalController?.terminate()
            clearNotification(paneID: $0.id)
        }
        tabs.removeAll { $0.id == tab.id }
        if activeTabID == tab.id {
            activeTabID = tabs.last?.id
        }
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        SessionPersistence.save(appState: self)
    }

    func addNotification(paneID: UUID, paneName: String, tabID: UUID, tabName: String, isPriority: Bool) {
        if notifications.contains(where: { $0.paneID == paneID }) {
            DebugLogger.shared.log(
                "[notify] addNotification skipped duplicate paneID=\(paneID.uuidString) name=\(paneName)",
                paneID: paneID
            )
            return
        }
        notifications.append(PaneNotification(
            paneID: paneID,
            paneName: paneName,
            tabID: tabID,
            tabName: tabName,
            isPriority: isPriority
        ))
        DebugLogger.shared.log(
            "[notify] addNotification appended pane=\(paneName) tab=\(tabName) priority=\(isPriority) paneID=\(paneID.uuidString)",
            paneID: paneID
        )
        MacNotificationCoordinator.shared.postPaneAttentionIfNeeded(
            paneID: paneID,
            paneName: paneName,
            tabID: tabID,
            tabName: tabName
        )
    }

    func clearNotification(paneID: UUID) {
        notifications.removeAll { $0.paneID == paneID }
    }

    func navigateTo(notification: PaneNotification) {
        switchToTab(id: notification.tabID)
        setActivePane(id: notification.paneID)
    }

    func focusPane(tabID: UUID, paneID: UUID) {
        switchToTab(id: tabID)
        setActivePane(id: paneID)
    }
}
