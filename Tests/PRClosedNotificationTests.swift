import XCTest

@testable import AgentSessionManager

@MainActor
private func restorePRClosedNotificationSettings(into settings: AppSettings) {
    guard let config = SettingsPersistence.load(NotificationConfig.self, from: "notification-settings.json") else {
        return
    }
    settings.isPRClosedNotificationsEnabled = config.isPRClosedNotificationsEnabled
}

@MainActor
final class PRClosedNotificationTests: XCTestCase {
    private var notificationSettingsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager/notification-settings.json")
    }

    override func setUp() {
        super.setUp()
        PersistenceHelpers.overrideAppSupportSubdirectory = "agent-session-manager"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: notificationSettingsURL)
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        super.tearDown()
    }

    func testClosedTransitionFiresCallback() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var firedCount = 0
        var capturedNumber: Int?
        var capturedTitle: String?
        monitor.onPRClosed = { number, title in
            firedCount += 1
            capturedNumber = number
            capturedTitle = title
        }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 42, title: "My PR"))
        XCTAssertEqual(firedCount, 0)

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "closed", number: 42, title: "My PR"))
        XCTAssertEqual(firedCount, 1)
        XCTAssertEqual(capturedNumber, 42)
        XCTAssertEqual(capturedTitle, "My PR")
    }

    func testNoFireOnFirstObservationAsClosed() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var firedCount = 0
        monitor.onPRClosed = { _, _ in firedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "closed", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 0)
    }

    func testNoDoubleFireForSameClose() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var firedCount = 0
        monitor.onPRClosed = { _, _ in firedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "closed", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "closed", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 1)
    }

    func testMergedToClosedFiresClosedOnce() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var mergedCount = 0
        var closedCount = 0
        monitor.onPRMerged = { _, _ in mergedCount += 1 }
        monitor.onPRClosed = { _, _ in closedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(mergedCount, 1)
        XCTAssertEqual(closedCount, 0)

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "closed", number: 1, title: "PR"))
        XCTAssertEqual(mergedCount, 1)
        XCTAssertEqual(closedCount, 1)
    }

    func testOnPRReopenedFiresOnClosedToOpenTransition() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var reopenedCount = 0
        monitor.onPRReopened = { reopenedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "closed"))
        XCTAssertEqual(reopenedCount, 0, "Should not fire while closed")

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        XCTAssertEqual(reopenedCount, 1, "Should fire once on closed→open transition")
    }

    func testAddPRClosedNotificationAppendsEntry() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addPRClosedNotification(
            paneID: paneID, paneName: "feature", tabID: tabID, tabName: "myapp",
            prNumber: 99, prTitle: "Add feature"
        )
        XCTAssertEqual(state.notifications.count, 1)
        let notification = state.notifications[0]
        XCTAssertEqual(notification.kind, .prClosed)
        XCTAssertEqual(notification.prNumber, 99)
        XCTAssertEqual(notification.prTitle, "Add feature")
        XCTAssertEqual(notification.paneID, paneID)
    }

    func testAddPRClosedNotificationDeduplicates() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addPRClosedNotification(
            paneID: paneID, paneName: "feature", tabID: tabID, tabName: "myapp",
            prNumber: 99, prTitle: "Add feature"
        )
        state.addPRClosedNotification(
            paneID: paneID, paneName: "feature", tabID: tabID, tabName: "myapp",
            prNumber: 99, prTitle: "Add feature"
        )
        XCTAssertEqual(state.notifications.count, 1)
    }

    func testAddPRClosedNotificationSkipsWhenSettingDisabled() throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let config = Data(
            """
            {"sidebarSide":"right","isPriorityEnabled":true,"isMacOSBannerEnabled":true,"isClaudeHookAttentionEnabled":true,"isPRClosedNotificationsEnabled":false}
            """.utf8)
        try config.write(to: notificationSettingsURL)

        let state = AppState()
        state.addPRClosedNotification(
            paneID: UUID(), paneName: "p", tabID: UUID(), tabName: "t",
            prNumber: 1, prTitle: "PR"
        )
        XCTAssertTrue(state.notifications.isEmpty)
    }

    func testPRClosedNotificationReplacesSamePaneAttention() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addNotification(paneID: paneID, paneName: "p", tabID: tabID, tabName: "t", isPriority: false)
        state.addPRClosedNotification(
            paneID: paneID, paneName: "p", tabID: tabID, tabName: "t",
            prNumber: 5, prTitle: "Fix"
        )
        XCTAssertEqual(state.notifications.count, 1)
        XCTAssertEqual(state.notifications[0].kind, .prClosed)
    }

    func testNotificationKindPRClosedCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(NotificationKind.prClosed)
        let decoded = try JSONDecoder().decode(NotificationKind.self, from: data)
        XCTAssertEqual(decoded, .prClosed)
    }

    func testAppSettingsPRClosedDefaultTrue() {
        let settings = AppSettings()
        XCTAssertTrue(settings.isPRClosedNotificationsEnabled)
    }

    func testNotificationSettingsPRClosedRoundTrip() {
        defer { try? FileManager.default.removeItem(at: notificationSettingsURL) }

        let settings = AppSettings()
        settings.isPRClosedNotificationsEnabled = false
        SettingsPersistence.saveNotificationSettings(appSettings: settings)

        let restored = AppSettings()
        restorePRClosedNotificationSettings(into: restored)
        XCTAssertFalse(restored.isPRClosedNotificationsEnabled)
    }

    func testLegacyNotificationSettingsDefaultsPRClosedEnabled() throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let legacy = Data(
            """
            {"sidebarSide":"right","isPriorityEnabled":true,"isMacOSBannerEnabled":true,"isClaudeHookAttentionEnabled":true}
            """.utf8)
        try legacy.write(to: notificationSettingsURL)

        let restored = AppSettings()
        restored.isPRClosedNotificationsEnabled = false
        restorePRClosedNotificationSettings(into: restored)
        XCTAssertTrue(restored.isPRClosedNotificationsEnabled)
    }

    func testIsPRClosedNotificationsEnabledHelperDefaultsTrue() {
        try? FileManager.default.removeItem(at: notificationSettingsURL)
        XCTAssertTrue(SettingsPersistence.isPRClosedNotificationsEnabled())
    }

    func testPaneIsClosedSetOnAddPRClosedNotification() {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "feature")
        state.tabs.append(tab)

        state.addPRClosedNotification(
            paneID: pane.id, paneName: "feature", tabID: tab.id, tabName: "T",
            prNumber: 7, prTitle: "Fix"
        )

        XCTAssertTrue(pane.isClosed)
    }

    func testClearPRClosedNotificationRemovesRowAndResetsFlag() {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "feature")
        state.tabs.append(tab)

        state.addPRClosedNotification(
            paneID: pane.id, paneName: "feature", tabID: tab.id, tabName: "T",
            prNumber: 7, prTitle: "Fix"
        )
        XCTAssertTrue(pane.isClosed)
        XCTAssertEqual(state.notifications.filter { $0.kind == .prClosed }.count, 1)

        state.clearPRClosedNotification(paneID: pane.id)

        XCTAssertFalse(pane.isClosed)
        XCTAssertFalse(state.notifications.contains { $0.kind == .prClosed })
    }

    func testClearPRClosedNotificationIsNoOpWhenNothingStale() {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "feature")
        state.tabs.append(tab)

        XCTAssertFalse(pane.isClosed)
        let before = state.notifications.count
        state.clearPRClosedNotification(paneID: pane.id)
        XCTAssertEqual(state.notifications.count, before)
        XCTAssertFalse(pane.isClosed)
    }

    func testPaneStaysClosedAfterClearNotification() {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "feature")
        state.tabs.append(tab)

        state.addPRClosedNotification(
            paneID: pane.id, paneName: "feature", tabID: tab.id, tabName: "T",
            prNumber: 7, prTitle: "Fix"
        )
        state.clearNotification(paneID: pane.id)

        XCTAssertTrue(pane.isClosed, "isClosed must survive notification clearance")
        XCTAssertTrue(state.notifications.isEmpty, "notification should be cleared")
    }

    func testPersistedPaneCarriesIsClosed() throws {
        let original = PersistedPane(
            id: UUID(), name: "feature", harness: .claude, isPriority: false, isMerged: false,
            isClosed: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: data)
        XCTAssertTrue(decoded.isClosed)
    }

    func testLegacyPersistedPaneDefaultsIsClosedFalse() throws {
        let json = Data(
            """
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "name": "feature",
              "harness": "claude",
              "isPriority": false,
              "isMerged": false
            }
            """.utf8)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertFalse(decoded.isClosed)
    }

    private func makePRJSON(state: String, number: Int = 1, title: String = "PR") -> Data {
        Data(
            """
            {"number":\(number),"title":"\(title)","state":"\(state)","url":"https://github.com/owner/repo/pull/\(number)"}
            """.utf8)
    }
}
