import Foundation
import XCTest
@testable import AgentSessionManager

@MainActor
final class SessionPersistenceNotificationTests: XCTestCase {

    func testDecodesLegacySessionWithoutPendingNotifications() throws {
        let json = """
        {"tabs":[],"activeTabIndex":null}
        """
        let data = Data(json.utf8)
        let session = try JSONDecoder().decode(PersistedSession.self, from: data)
        XCTAssertTrue(session.pendingNotifications.isEmpty)
    }

    func testPendingNotificationsRoundTrip() throws {
        let paneID = UUID()
        let tabID = UUID()
        let notifID = UUID()
        let ts = Date(timeIntervalSinceReferenceDate: 123_456)
        let pending = PersistedPaneNotification(
            notificationID: notifID,
            paneID: paneID,
            paneName: "p",
            tabID: tabID,
            tabName: "t",
            isPriority: true,
            timestamp: ts
        )
        let session = PersistedSession(
            tabs: [],
            activeTabIndex: nil,
            pendingNotifications: [pending]
        )
        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(PersistedSession.self, from: encoded)
        XCTAssertEqual(decoded.pendingNotifications.count, 1)
        XCTAssertEqual(decoded.pendingNotifications[0], pending)
    }

    func testRestoreUsesPersistedTabAndPaneIDs() {
        let tabID = UUID()
        let paneID = UUID()
        let tab = Tab(id: tabID, name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "P", id: paneID)
        XCTAssertEqual(tab.id, tabID)
        XCTAssertEqual(pane.id, paneID)
    }
}
