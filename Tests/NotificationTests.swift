import XCTest
@testable import AgentSessionManager

@MainActor
final class NotificationTests: XCTestCase {

    // MARK: - AppState notification management

    func testAddNotification() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addNotification(paneID: paneID, paneName: "auth-fix", tabID: tabID, tabName: "myapp", isPriority: false)
        XCTAssertEqual(state.notifications.count, 1)
        XCTAssertEqual(state.notifications[0].paneID, paneID)
        XCTAssertEqual(state.notifications[0].paneName, "auth-fix")
        XCTAssertEqual(state.notifications[0].tabName, "myapp")
        XCTAssertFalse(state.notifications[0].isPriority)
    }

    func testAddNotificationDeduplication() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addNotification(paneID: paneID, paneName: "auth-fix", tabID: tabID, tabName: "myapp", isPriority: false)
        state.addNotification(paneID: paneID, paneName: "auth-fix", tabID: tabID, tabName: "myapp", isPriority: false)
        XCTAssertEqual(state.notifications.count, 1)
    }

    func testAddNotificationSkipsActivePane() {
        let state = AppState()
        let paneID = UUID()
        state.activePaneID = paneID
        state.addNotification(paneID: paneID, paneName: "auth-fix", tabID: UUID(), tabName: "myapp", isPriority: false)
        XCTAssertTrue(state.notifications.isEmpty)
    }

    func testClearNotification() {
        let state = AppState()
        let paneID = UUID()
        state.addNotification(paneID: paneID, paneName: "auth-fix", tabID: UUID(), tabName: "myapp", isPriority: false)
        state.clearNotification(paneID: paneID)
        XCTAssertTrue(state.notifications.isEmpty)
    }

    func testClearNotificationOnlyRemovesTargetPane() {
        let state = AppState()
        let pane1 = UUID()
        let pane2 = UUID()
        let tabID = UUID()
        state.addNotification(paneID: pane1, paneName: "pane1", tabID: tabID, tabName: "myapp", isPriority: false)
        state.addNotification(paneID: pane2, paneName: "pane2", tabID: tabID, tabName: "myapp", isPriority: false)
        state.clearNotification(paneID: pane1)
        XCTAssertEqual(state.notifications.count, 1)
        XCTAssertEqual(state.notifications[0].paneID, pane2)
    }

    func testSetActivePaneClearsNotification() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addNotification(paneID: paneID, paneName: "auth-fix", tabID: tabID, tabName: "myapp", isPriority: false)
        XCTAssertEqual(state.notifications.count, 1)
        state.setActivePane(id: paneID)
        XCTAssertTrue(state.notifications.isEmpty)
    }

    func testSetActivePaneNilDoesNotClear() {
        let state = AppState()
        let paneID = UUID()
        state.addNotification(paneID: paneID, paneName: "auth-fix", tabID: UUID(), tabName: "myapp", isPriority: false)
        state.setActivePane(id: nil)
        XCTAssertEqual(state.notifications.count, 1)
    }

    func testPriorityNotification() {
        let state = AppState()
        state.addNotification(paneID: UUID(), paneName: "pane1", tabID: UUID(), tabName: "myapp", isPriority: true)
        XCTAssertTrue(state.notifications[0].isPriority)
    }

    // MARK: - AppSettings defaults

    func testNotificationSettingsDefaults() {
        let settings = AppSettings()
        XCTAssertEqual(settings.notificationSidebarSide, .right)
        XCTAssertTrue(settings.isPriorityNotificationsEnabled)
        XCTAssertTrue(settings.isMacOSBannerNotificationsEnabled)
    }

    // MARK: - PersistedPane isPriority round-trip

    func testPersistedPaneIsPriorityRoundTrip() throws {
        let pane = PersistedPane(id: UUID(), name: "test", cliType: .claude, isPriority: true)
        let data = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: data)
        XCTAssertTrue(decoded.isPriority)
    }

    func testPersistedPaneIsPriorityDefaultsFalse() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"test","cliType":"claude"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertFalse(decoded.isPriority)
    }

    // MARK: - SidebarSide

    func testSidebarSideCodable() throws {
        let encoded = try JSONEncoder().encode(SidebarSide.left)
        let decoded = try JSONDecoder().decode(SidebarSide.self, from: encoded)
        XCTAssertEqual(decoded, .left)
    }

    func testSidebarSideDisplayNames() {
        XCTAssertEqual(SidebarSide.left.displayName, "Left")
        XCTAssertEqual(SidebarSide.right.displayName, "Right")
    }

    // MARK: - PaneNotification

    func testPaneNotificationHasUniqueIDs() {
        let tabID = UUID()
        let paneID = UUID()
        let n1 = PaneNotification(paneID: paneID, paneName: "pane", tabID: tabID, tabName: "tab", isPriority: false)
        let n2 = PaneNotification(paneID: paneID, paneName: "pane", tabID: tabID, tabName: "tab", isPriority: false)
        XCTAssertNotEqual(n1.id, n2.id)
    }
}
