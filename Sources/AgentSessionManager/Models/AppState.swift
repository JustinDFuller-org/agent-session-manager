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
        if let id {
            clearNotification(paneID: id)
            MacNotificationCoordinator.shared.removeDeliveredNotifications(forPaneID: id)
        }
    }

    func isWorktreeDuplicate(directory: URL, name: String) -> Bool {
        tabs.contains { $0.directory == directory && $0.hasPaneNamed(name) }
    }

    /// True if a pane in that tab already uses this checkout directory.
    func isCheckoutInUse(directory: URL, checkout: URL, excludingPaneID: UUID? = nil) -> Bool {
        let normalized = checkout.standardizedFileURL
        return tabs.contains { tab in
            guard tab.directory == directory else { return false }
            return tab.panes.contains { pane in
                if let excludingPaneID, pane.id == excludingPaneID { return false }
                return pane.worktreePath?.standardizedFileURL == normalized
            }
        }
    }

    func closeTab(_ tab: Tab) {
        let paneIDs = Set(tab.panes.map(\.id))
        for pane in tab.panes {
            pane.terminalController?.terminate()
        }
        notifications.removeAll { paneIDs.contains($0.paneID) }
        tabs.removeAll { $0.id == tab.id }
        if activeTabID == tab.id {
            activeTabID = tabs.last?.id
        }
        SessionPersistence.save(appState: self)
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        SessionPersistence.save(appState: self)
    }

    func addNotification(
        paneID: UUID, paneName: String, tabID: UUID, tabName: String, isPriority: Bool,
        event: PaneAttentionEvent = .rawBell
    ) {
        if notifications.contains(where: { $0.paneID == paneID && $0.kind == .prMerged }) {
            return
        }
        let notification =
            PaneNotification(
                paneID: paneID,
                paneName: paneName,
                tabID: tabID,
                tabName: tabName,
                isPriority: isPriority,
                reason: event.reason
            )
        if let index = notifications.firstIndex(where: { $0.paneID == paneID }) {
            notifications[index] = notification
        } else {
            notifications.append(notification)
        }
        TracingService.shared.record(
            "pane.notification.added",
            attributes: [
                "pane.name": paneName,
                "tab.name": tabName,
                "notification.kind": "attention",
                "notification.source": event.source.rawValue,
                "notification.reason": event.reason,
            ])
        MacNotificationCoordinator.shared.postPaneAttentionIfNeeded(
            paneID: paneID,
            paneName: paneName,
            tabID: tabID,
            tabName: tabName,
            reason: event.reason,
            source: event.source
        )
        SessionPersistence.save(appState: self)
    }

    func addPRMergedNotification(
        paneID: UUID,
        paneName: String,
        tabID: UUID,
        tabName: String,
        prNumber: Int,
        prTitle: String
    ) {
        guard SettingsPersistence.isPRMergedNotificationsEnabled() else { return }
        if notifications.contains(where: { $0.paneID == paneID && $0.kind == .prMerged }) { return }
        notifications.removeAll { $0.paneID == paneID }
        notifications.append(
            PaneNotification(
                paneID: paneID,
                paneName: paneName,
                tabID: tabID,
                tabName: tabName,
                isPriority: false,
                kind: .prMerged,
                prNumber: prNumber,
                prTitle: prTitle
            ))
        tabs.flatMap(\.panes).first { $0.id == paneID }?.isMerged = true
        MacNotificationCoordinator.shared.postPRMergedBannerIfNeeded(
            paneID: paneID,
            paneName: paneName,
            tabID: tabID,
            tabName: tabName,
            prNumber: prNumber,
            prTitle: prTitle
        )
        SessionPersistence.save(appState: self)
    }

    func clearNotification(paneID: UUID) {
        if let notification = notifications.first(where: { $0.paneID == paneID }) {
            TracingService.shared.record(
                "pane.notification.cleared",
                attributes: [
                    "pane.name": notification.paneName,
                    "tab.name": notification.tabName,
                    "reason": "cleared",
                ])
        }
        notifications.removeAll { $0.paneID == paneID }
        SessionPersistence.save(appState: self)
    }

    func clearAllNotifications() {
        notifications.removeAll()
        SessionPersistence.save(appState: self)
    }

    func navigateTo(notification: PaneNotification) {
        TracingService.shared.record(
            "pane.notification.cleared",
            attributes: [
                "pane.name": notification.paneName,
                "tab.name": notification.tabName,
                "reason": "navigated",
            ])
        switchToTab(id: notification.tabID)
        setActivePane(id: notification.paneID)
        if notification.kind == .prMerged {
            NotificationCenter.default.post(
                name: .prMergedActionRequested,
                object: nil,
                userInfo: [
                    "paneID": notification.paneID.uuidString,
                    "tabID": notification.tabID.uuidString,
                ]
            )
        }
    }

    func focusPane(tabID: UUID, paneID: UUID) {
        TracingService.shared.record("pane.activated", attributes: ["pane.name": "", "tab.name": ""])
        switchToTab(id: tabID)
        setActivePane(id: paneID)
    }
}
