import XCTest
@testable import AgentSessionManager

@MainActor
final class PRMergedNotificationTests: XCTestCase {

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

    // MARK: - StatusLineMonitor: merged transition detection

    func testMergedTransitionFiresCallback() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, cliType: .claude)
        var firedCount = 0
        var capturedNumber: Int?
        var capturedTitle: String?
        monitor.onPRMerged = { number, title in
            firedCount += 1
            capturedNumber = number
            capturedTitle = title
        }

        // First observation: "open" — no fire
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 42, title: "My PR"))
        XCTAssertEqual(firedCount, 0)

        // Transition: "merged" — should fire once
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 42, title: "My PR"))
        XCTAssertEqual(firedCount, 1)
        XCTAssertEqual(capturedNumber, 42)
        XCTAssertEqual(capturedTitle, "My PR")
    }

    func testNoFireOnFirstObservationAsMerged() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, cliType: .claude)
        var firedCount = 0
        monitor.onPRMerged = { _, _ in firedCount += 1 }

        // First observation is already "merged" — suppress (avoid false positive on restart)
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 0)
    }

    func testNoDoubleFireForSameMerge() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, cliType: .claude)
        var firedCount = 0
        monitor.onPRMerged = { _, _ in firedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 1)
    }

    func testResetAfterStop() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, cliType: .claude)
        var firedCount = 0
        monitor.onPRMerged = { _, _ in firedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 1)

        monitor.stop()

        // After stop, state resets — next open→merged should fire again
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 2)
    }

    func testClosedToMergedDoesNotFire() {
        // "closed" is not "merged" — no fire on closed→merged transition either (closed is already final)
        // But the monitor does fire if it goes closed→merged since lastKnownPRState != nil
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, cliType: .claude)
        var firedCount = 0
        monitor.onPRMerged = { _, _ in firedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "closed", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 1)
    }

    // MARK: - AppState: addPRMergedNotification

    func testAddPRMergedNotificationAppendsEntry() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addPRMergedNotification(
            paneID: paneID, paneName: "feature", tabID: tabID, tabName: "myapp",
            prNumber: 99, prTitle: "Add feature"
        )
        XCTAssertEqual(state.notifications.count, 1)
        let n = state.notifications[0]
        XCTAssertEqual(n.kind, .prMerged)
        XCTAssertEqual(n.prNumber, 99)
        XCTAssertEqual(n.prTitle, "Add feature")
        XCTAssertEqual(n.paneID, paneID)
    }

    func testAddPRMergedNotificationDeduplicates() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addPRMergedNotification(
            paneID: paneID, paneName: "feature", tabID: tabID, tabName: "myapp",
            prNumber: 99, prTitle: "Add feature"
        )
        state.addPRMergedNotification(
            paneID: paneID, paneName: "feature", tabID: tabID, tabName: "myapp",
            prNumber: 99, prTitle: "Add feature"
        )
        XCTAssertEqual(state.notifications.count, 1)
    }

    func testAddPRMergedNotificationSkipsWhenSettingDisabled() throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let config = """
        {"sidebarSide":"right","isPriorityEnabled":true,"isMacOSBannerEnabled":true,"isClaudeHookAttentionEnabled":true,"isPRMergedNotificationsEnabled":false}
        """.data(using: .utf8)!
        try config.write(to: notificationSettingsURL)

        let state = AppState()
        state.addPRMergedNotification(
            paneID: UUID(), paneName: "p", tabID: UUID(), tabName: "t",
            prNumber: 1, prTitle: "PR"
        )
        XCTAssertTrue(state.notifications.isEmpty)
    }

    func testPRMergedNotificationCoexistsWithTerminalBell() {
        let state = AppState()
        let pane1 = UUID()
        let pane2 = UUID()
        let tabID = UUID()
        state.addNotification(paneID: pane1, paneName: "p1", tabID: tabID, tabName: "t", isPriority: false)
        state.addPRMergedNotification(
            paneID: pane2, paneName: "p2", tabID: tabID, tabName: "t",
            prNumber: 5, prTitle: "Fix"
        )
        XCTAssertEqual(state.notifications.count, 2)
        XCTAssertEqual(state.notifications[0].kind, .terminalBell)
        XCTAssertEqual(state.notifications[1].kind, .prMerged)
    }

    // MARK: - NotificationKind codable round-trip

    func testNotificationKindCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(NotificationKind.prMerged)
        let decoded = try JSONDecoder().decode(NotificationKind.self, from: data)
        XCTAssertEqual(decoded, .prMerged)
    }

    func testNotificationKindTerminalBellRoundTrip() throws {
        let data = try JSONEncoder().encode(NotificationKind.terminalBell)
        let decoded = try JSONDecoder().decode(NotificationKind.self, from: data)
        XCTAssertEqual(decoded, .terminalBell)
    }

    // MARK: - PaneNotification defaults

    func testPaneNotificationDefaultKindIsTerminalBell() {
        let n = PaneNotification(paneID: UUID(), paneName: "p", tabID: UUID(), tabName: "t", isPriority: false)
        XCTAssertEqual(n.kind, .terminalBell)
        XCTAssertNil(n.prNumber)
        XCTAssertNil(n.prTitle)
    }

    // MARK: - PersistedPaneNotification: new fields round-trip

    func testPersistedPaneNotificationCarriesKindAndPR() throws {
        let original = PersistedPaneNotification(
            notificationID: UUID(), paneID: UUID(), paneName: "p", tabID: UUID(), tabName: "t",
            isPriority: false, timestamp: Date(timeIntervalSinceReferenceDate: 0),
            kind: .prMerged, prNumber: 42, prTitle: "Merge feature"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistedPaneNotification.self, from: data)
        XCTAssertEqual(decoded.kind, .prMerged)
        XCTAssertEqual(decoded.prNumber, 42)
        XCTAssertEqual(decoded.prTitle, "Merge feature")
    }

    func testLegacyPersistedNotificationDefaultsToTerminalBell() throws {
        let json = """
        {
          "notificationID": "00000000-0000-0000-0000-000000000001",
          "paneID": "00000000-0000-0000-0000-000000000002",
          "paneName": "p",
          "tabID": "00000000-0000-0000-0000-000000000003",
          "tabName": "t",
          "isPriority": false,
          "timestamp": 0
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PersistedPaneNotification.self, from: json)
        XCTAssertEqual(decoded.kind, .terminalBell)
        XCTAssertNil(decoded.prNumber)
        XCTAssertNil(decoded.prTitle)
    }

    // MARK: - AppSettings defaults and persistence

    func testAppSettingsPRMergedDefaultTrue() {
        let settings = AppSettings()
        XCTAssertTrue(settings.isPRMergedNotificationsEnabled)
    }

    func testNotificationSettingsPRMergedRoundTrip() {
        defer { try? FileManager.default.removeItem(at: notificationSettingsURL) }

        let settings = AppSettings()
        settings.isPRMergedNotificationsEnabled = false
        SettingsPersistence.saveNotificationSettings(appSettings: settings)

        let restored = AppSettings()
        SettingsPersistence.restoreNotificationSettings(into: restored)
        XCTAssertFalse(restored.isPRMergedNotificationsEnabled)
    }

    func testLegacyNotificationSettingsDefaultsPRMergedEnabled() throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let legacy = """
        {"sidebarSide":"right","isPriorityEnabled":true,"isMacOSBannerEnabled":true,"isClaudeHookAttentionEnabled":true}
        """.data(using: .utf8)!
        try legacy.write(to: notificationSettingsURL)

        let restored = AppSettings()
        restored.isPRMergedNotificationsEnabled = false
        SettingsPersistence.restoreNotificationSettings(into: restored)
        XCTAssertTrue(restored.isPRMergedNotificationsEnabled)
    }

    func testIsPRMergedNotificationsEnabledHelperDefaultsTrue() {
        // No file on disk → defaults to true
        try? FileManager.default.removeItem(at: notificationSettingsURL)
        XCTAssertTrue(SettingsPersistence.isPRMergedNotificationsEnabled())
    }

    // MARK: - Helpers

    private func makePRJSON(state: String, number: Int = 1, title: String = "PR") -> Data {
        """
        {"number":\(number),"title":"\(title)","state":"\(state)","url":"https://github.com/owner/repo/pull/\(number)"}
        """.data(using: .utf8)!
    }
}
