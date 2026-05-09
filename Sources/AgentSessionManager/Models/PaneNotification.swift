import Foundation

struct PaneNotification: Identifiable {
    let id: UUID
    let paneID: UUID
    let paneName: String
    let tabID: UUID
    let tabName: String
    let isPriority: Bool
    let timestamp: Date

    init(paneID: UUID, paneName: String, tabID: UUID, tabName: String, isPriority: Bool) {
        self.init(
            id: UUID(),
            paneID: paneID,
            paneName: paneName,
            tabID: tabID,
            tabName: tabName,
            isPriority: isPriority,
            timestamp: Date()
        )
    }

    init(
        id: UUID,
        paneID: UUID,
        paneName: String,
        tabID: UUID,
        tabName: String,
        isPriority: Bool,
        timestamp: Date
    ) {
        self.id = id
        self.paneID = paneID
        self.paneName = paneName
        self.tabID = tabID
        self.tabName = tabName
        self.isPriority = isPriority
        self.timestamp = timestamp
    }
}
