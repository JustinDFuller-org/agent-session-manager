import Foundation

enum NotificationKind: String, Codable {
    case terminalBell
    case prMerged
}

struct PaneNotification: Identifiable {
    let id: UUID
    let paneID: UUID
    let paneName: String
    let tabID: UUID
    let tabName: String
    let isPriority: Bool
    let timestamp: Date
    let kind: NotificationKind
    let prNumber: Int?
    let prTitle: String?

    init(
        paneID: UUID,
        paneName: String,
        tabID: UUID,
        tabName: String,
        isPriority: Bool,
        kind: NotificationKind = .terminalBell,
        prNumber: Int? = nil,
        prTitle: String? = nil
    ) {
        self.init(
            id: UUID(),
            paneID: paneID,
            paneName: paneName,
            tabID: tabID,
            tabName: tabName,
            isPriority: isPriority,
            timestamp: Date(),
            kind: kind,
            prNumber: prNumber,
            prTitle: prTitle
        )
    }

    init(
        id: UUID,
        paneID: UUID,
        paneName: String,
        tabID: UUID,
        tabName: String,
        isPriority: Bool,
        timestamp: Date,
        kind: NotificationKind = .terminalBell,
        prNumber: Int? = nil,
        prTitle: String? = nil
    ) {
        self.id = id
        self.paneID = paneID
        self.paneName = paneName
        self.tabID = tabID
        self.tabName = tabName
        self.isPriority = isPriority
        self.timestamp = timestamp
        self.kind = kind
        self.prNumber = prNumber
        self.prTitle = prTitle
    }
}
