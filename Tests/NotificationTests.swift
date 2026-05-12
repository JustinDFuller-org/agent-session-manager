import XCTest

@testable import AgentSessionManager

@MainActor
final class NotificationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PersistenceHelpers.overrideAppSupportSubdirectory = "agent-session-manager"
    }

    override func tearDown() {
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        super.tearDown()
    }

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

    func testAddNotificationIncludesActivePane() {
        let state = AppState()
        let paneID = UUID()
        state.activePaneID = paneID
        state.addNotification(paneID: paneID, paneName: "auth-fix", tabID: UUID(), tabName: "myapp", isPriority: false)
        XCTAssertEqual(state.notifications.count, 1)
        XCTAssertEqual(state.notifications[0].paneID, paneID)
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
        XCTAssertTrue(settings.alwaysShowNotificationsSidebar)
    }

    func testStickyNotificationsDefaultIsFalse() {
        XCTAssertFalse(AppSettings().isStickyNotificationsEnabled)
    }

    func testStickyNotificationsPersists() {
        let notificationURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager/notification-settings.json")
        defer { try? FileManager.default.removeItem(at: notificationURL) }

        let settings = AppSettings()
        settings.isStickyNotificationsEnabled = true
        SettingsPersistence.saveNotificationSettings(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restoreNotificationSettings(into: restored)
        XCTAssertTrue(restored.isStickyNotificationsEnabled)
    }

    func testNotificationSettingsPersistRoundTrip() {
        let notificationURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager/notification-settings.json")
        defer { try? FileManager.default.removeItem(at: notificationURL) }

        let settings = AppSettings()
        settings.notificationSidebarSide = .left
        settings.isPriorityNotificationsEnabled = false
        settings.isMacOSBannerNotificationsEnabled = false
        settings.alwaysShowNotificationsSidebar = false
        SettingsPersistence.saveNotificationSettings(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restoreNotificationSettings(into: restored)
        XCTAssertEqual(restored.notificationSidebarSide, .left)
        XCTAssertFalse(restored.isPriorityNotificationsEnabled)
        XCTAssertFalse(restored.isMacOSBannerNotificationsEnabled)
        XCTAssertFalse(restored.alwaysShowNotificationsSidebar)
    }

    func testAlwaysShowNotificationsSidebarRoundTrip() {
        let notificationURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager/notification-settings.json")
        defer { try? FileManager.default.removeItem(at: notificationURL) }

        let settings = AppSettings()
        settings.alwaysShowNotificationsSidebar = true
        SettingsPersistence.saveNotificationSettings(appSettings: settings)

        let restored = AppSettings()
        restored.alwaysShowNotificationsSidebar = false
        SettingsPersistence.restoreNotificationSettings(into: restored)
        XCTAssertTrue(restored.alwaysShowNotificationsSidebar)
    }

    func testAlwaysShowNotificationsSidebarLegacyJSONDefaultsTrue() throws {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let url = support.appending(path: "notification-settings.json")
        defer { try? FileManager.default.removeItem(at: url) }

        let legacy = Data(
            """
            {"sidebarSide":"right","isPriorityEnabled":true,"isMacOSBannerEnabled":true,"isClaudeHookAttentionEnabled":true,"isPRMergedNotificationsEnabled":true}
            """.utf8)
        try legacy.write(to: url)

        let restored = AppSettings()
        restored.alwaysShowNotificationsSidebar = false
        SettingsPersistence.restoreNotificationSettings(into: restored)
        XCTAssertTrue(restored.alwaysShowNotificationsSidebar)
    }

    /// Older `notification-settings.json` files did not encode the macOS banner flag; it should default on.
    func testNotificationSettingsLegacyJSONDefaultsMacOSBannerOn() throws {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let url = support.appending(path: "notification-settings.json")
        defer { try? FileManager.default.removeItem(at: url) }

        let legacy = Data(
            """
            {"sidebarSide":"left","isPriorityEnabled":true}
            """.utf8)
        try legacy.write(to: url)

        let restored = AppSettings()
        restored.isMacOSBannerNotificationsEnabled = false
        SettingsPersistence.restoreNotificationSettings(into: restored)
        XCTAssertEqual(restored.notificationSidebarSide, .left)
        XCTAssertTrue(restored.isPriorityNotificationsEnabled)
        XCTAssertTrue(restored.isMacOSBannerNotificationsEnabled)
    }

    // MARK: - PersistedPane isPriority round-trip

    func testPersistedPaneIsPriorityRoundTrip() throws {
        let pane = PersistedPane(id: UUID(), name: "test", cliType: .claude, isPriority: true)
        let data = try JSONEncoder().encode(pane)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: data)
        XCTAssertTrue(decoded.isPriority)
    }

    func testPersistedPaneIsPriorityDefaultsFalse() throws {
        let json = Data(
            """
            {"id":"00000000-0000-0000-0000-000000000001","name":"test","cliType":"claude"}
            """.utf8)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertFalse(decoded.isPriority)
    }

    // MARK: - Clear notification on user input

    func testUserInputClearsNotificationForActivePane() {
        let state = AppState()
        let paneID = UUID()
        state.addNotification(paneID: paneID, paneName: "fix", tabID: UUID(), tabName: "myapp", isPriority: false)
        XCTAssertEqual(state.notifications.count, 1)
        // Simulate the onUserInput closure that wireTerminalBellForNotifications installs.
        state.clearNotification(paneID: paneID)
        XCTAssertTrue(state.notifications.isEmpty)
    }

    func testUserInputIsNoOpWhenNoNotification() {
        let state = AppState()
        let paneID = UUID()
        // No notification present — clearNotification should be safe to call.
        state.clearNotification(paneID: paneID)
        XCTAssertTrue(state.notifications.isEmpty)
    }

    func testUserInputInPaneDoesNotClearOtherPanesNotifications() {
        let state = AppState()
        let typingPane = UUID()
        let otherPane = UUID()
        let tabID = UUID()
        state.addNotification(paneID: otherPane, paneName: "other", tabID: tabID, tabName: "myapp", isPriority: false)
        // Simulate user typing in typingPane — should not affect otherPane's notification.
        state.clearNotification(paneID: typingPane)
        XCTAssertEqual(state.notifications.count, 1)
        XCTAssertEqual(state.notifications[0].paneID, otherPane)
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
