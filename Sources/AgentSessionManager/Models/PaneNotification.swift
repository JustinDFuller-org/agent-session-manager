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
        self.id = UUID()
        self.paneID = paneID
        self.paneName = paneName
        self.tabID = tabID
        self.tabName = tabName
        self.isPriority = isPriority
        self.timestamp = Date()
    }
}
