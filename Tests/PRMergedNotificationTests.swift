import XCTest

@testable import AgentSessionManager

@MainActor
private func restorePRMergedNotificationSettings(into settings: AppSettings) {
    guard let config = SettingsPersistence.load(NotificationConfig.self, from: "notification-settings.json") else {
        return
    }
    settings.isPRMergedNotificationsEnabled = config.isPRMergedNotificationsEnabled
}

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

    func testMergedTransitionFiresCallback() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var firedCount = 0
        var capturedNumber: Int?
        var capturedTitle: String?
        monitor.onPRMerged = { number, title in
            firedCount += 1
            capturedNumber = number
            capturedTitle = title
        }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 42, title: "My PR"))
        XCTAssertEqual(firedCount, 0)

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 42, title: "My PR"))
        XCTAssertEqual(firedCount, 1)
        XCTAssertEqual(capturedNumber, 42)
        XCTAssertEqual(capturedTitle, "My PR")
    }

    func testDeferredPaneSetupWiresMergedTransitionNotification() async {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = tab.addPaneWithLoadingState(name: "feature", harness: .claude)
        state.tabs.append(tab)
        pane.bindNotifications(appState: state, isPriority: false)

        tab.completeSetup(
            for: pane,
            resolved: ResolvedWorktree(
                paneTitle: "feature",
                processDirectory: URL(filePath: "/tmp/feature"),
                checkoutURL: URL(filePath: "/tmp/feature"),
                isExternalTakeover: false
            ),
            managed: true,
            effectiveExtraArgs: [],
            extraEnvVars: [:],
            statusLineConfigOverride: nil
        )

        pane.statusLineMonitor?.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        pane.statusLineMonitor?.simulatePRUpdateForTesting(makePRJSON(state: "merged"))
        await Task.yield()

        XCTAssertEqual(state.notifications.count, 1)
        XCTAssertEqual(state.notifications.first?.kind, .prMerged)
    }

    func testReplacingStatusMonitorRewiresMergedTransitionNotification() async {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "feature", tab: tab, harness: .claude)
        tab.panes.append(pane)
        state.tabs.append(tab)
        pane.bindNotifications(appState: state, isPriority: false)

        let old = StatusLineMonitor(paneID: pane.id, workingDirectory: nil, harness: .claude)
        pane.installStatusLineMonitor(old)
        pane.installStatusLineMonitor(
            StatusLineMonitor(paneID: pane.id, workingDirectory: nil, harness: .claude))

        old.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        old.simulatePRUpdateForTesting(makePRJSON(state: "merged"))
        await Task.yield()
        XCTAssertTrue(state.notifications.isEmpty)

        pane.statusLineMonitor?.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        pane.statusLineMonitor?.simulatePRUpdateForTesting(makePRJSON(state: "merged"))
        await Task.yield()

        XCTAssertEqual(state.notifications.count, 1)
        XCTAssertEqual(state.notifications.first?.kind, .prMerged)
    }

    func testNoFireOnFirstObservationAsMerged() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var firedCount = 0
        monitor.onPRMerged = { _, _ in firedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 0)
    }

    func testNoDoubleFireForSameMerge() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var firedCount = 0
        monitor.onPRMerged = { _, _ in firedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 1)
    }

    func testResetAfterStop() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var firedCount = 0
        monitor.onPRMerged = { _, _ in firedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 1)

        monitor.stop()

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 2)
    }

    func testClosedToMergedDoesNotFire() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var firedCount = 0
        monitor.onPRMerged = { _, _ in firedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "closed", number: 1, title: "PR"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged", number: 1, title: "PR"))
        XCTAssertEqual(firedCount, 1)
    }

    func testAddPRMergedNotificationAppendsEntry() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addPRMergedNotification(
            paneID: paneID, paneName: "feature", tabID: tabID, tabName: "myapp",
            prNumber: 99, prTitle: "Add feature"
        )
        XCTAssertEqual(state.notifications.count, 1)
        let notification = state.notifications[0]
        XCTAssertEqual(notification.kind, .prMerged)
        XCTAssertEqual(notification.prNumber, 99)
        XCTAssertEqual(notification.prTitle, "Add feature")
        XCTAssertEqual(notification.paneID, paneID)
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
        let config = Data(
            """
            {"sidebarSide":"right","isPriorityEnabled":true,"isMacOSBannerEnabled":true,"isClaudeHookAttentionEnabled":true,"isPRMergedNotificationsEnabled":false}
            """.utf8)
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

    func testPRMergedNotificationReplacesSamePaneAttention() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addNotification(paneID: paneID, paneName: "p", tabID: tabID, tabName: "t", isPriority: false)
        state.addPRMergedNotification(
            paneID: paneID, paneName: "p", tabID: tabID, tabName: "t",
            prNumber: 5, prTitle: "Fix"
        )
        XCTAssertEqual(state.notifications.count, 1)
        XCTAssertEqual(state.notifications[0].kind, .prMerged)
    }

    func testAttentionDoesNotReplaceSamePanePRMergedNotification() {
        let state = AppState()
        let paneID = UUID()
        let tabID = UUID()
        state.addPRMergedNotification(
            paneID: paneID, paneName: "p", tabID: tabID, tabName: "t",
            prNumber: 5, prTitle: "Fix"
        )
        state.addNotification(
            paneID: paneID, paneName: "p", tabID: tabID, tabName: "t", isPriority: false,
            event: PaneAttentionEvent(source: .osc777, reason: "Lower priority")
        )
        XCTAssertEqual(state.notifications.count, 1)
        XCTAssertEqual(state.notifications[0].kind, .prMerged)
    }

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

    func testPaneNotificationDefaultKindIsTerminalBell() {
        let notification = PaneNotification(
            paneID: UUID(), paneName: "p", tabID: UUID(), tabName: "t", isPriority: false)
        XCTAssertEqual(notification.kind, .terminalBell)
        XCTAssertNil(notification.prNumber)
        XCTAssertNil(notification.prTitle)
    }

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
        let json = Data(
            """
            {
              "notificationID": "00000000-0000-0000-0000-000000000001",
              "paneID": "00000000-0000-0000-0000-000000000002",
              "paneName": "p",
              "tabID": "00000000-0000-0000-0000-000000000003",
              "tabName": "t",
              "isPriority": false,
              "timestamp": 0
            }
            """.utf8)
        let decoded = try JSONDecoder().decode(PersistedPaneNotification.self, from: json)
        XCTAssertEqual(decoded.kind, .terminalBell)
        XCTAssertNil(decoded.prNumber)
        XCTAssertNil(decoded.prTitle)
    }

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
        restorePRMergedNotificationSettings(into: restored)
        XCTAssertFalse(restored.isPRMergedNotificationsEnabled)
    }

    func testLegacyNotificationSettingsDefaultsPRMergedEnabled() throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let legacy = Data(
            """
            {"sidebarSide":"right","isPriorityEnabled":true,"isMacOSBannerEnabled":true,"isClaudeHookAttentionEnabled":true}
            """.utf8)
        try legacy.write(to: notificationSettingsURL)

        let restored = AppSettings()
        restored.isPRMergedNotificationsEnabled = false
        restorePRMergedNotificationSettings(into: restored)
        XCTAssertTrue(restored.isPRMergedNotificationsEnabled)
    }

    func testIsPRMergedNotificationsEnabledHelperDefaultsTrue() {
        try? FileManager.default.removeItem(at: notificationSettingsURL)
        XCTAssertTrue(SettingsPersistence.isPRMergedNotificationsEnabled())
    }

    func testPaneIsMergedSetOnAddPRMergedNotification() {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "feature")
        state.tabs.append(tab)

        state.addPRMergedNotification(
            paneID: pane.id, paneName: "feature", tabID: tab.id, tabName: "T",
            prNumber: 7, prTitle: "Fix"
        )

        XCTAssertTrue(pane.isMerged)
    }

    func testClearPRMergedNotificationRemovesRowAndResetsFlag() {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "feature")
        state.tabs.append(tab)

        state.addPRMergedNotification(
            paneID: pane.id, paneName: "feature", tabID: tab.id, tabName: "T",
            prNumber: 7, prTitle: "Fix"
        )
        XCTAssertTrue(pane.isMerged)
        XCTAssertEqual(state.notifications.filter { $0.kind == .prMerged }.count, 1)

        state.clearPRMergedNotification(paneID: pane.id)

        XCTAssertFalse(pane.isMerged)
        XCTAssertFalse(state.notifications.contains { $0.kind == .prMerged })
    }

    func testClearPRMergedNotificationIsNoOpWhenNothingStale() {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "feature")
        state.tabs.append(tab)

        XCTAssertFalse(pane.isMerged)
        let before = state.notifications.count
        state.clearPRMergedNotification(paneID: pane.id)
        XCTAssertEqual(state.notifications.count, before)
        XCTAssertFalse(pane.isMerged)
    }

    func testOnPRReopenedFiresOnMergedToOpenTransition() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var reopenedCount = 0
        monitor.onPRReopened = { reopenedCount += 1 }

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged"))
        XCTAssertEqual(reopenedCount, 0, "Should not fire while merged")

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        XCTAssertEqual(reopenedCount, 1, "Should fire once on merged→open transition")

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        XCTAssertEqual(reopenedCount, 1)
    }

    func testOnPRReopenedRearmsMergedNotification() {
        let monitor = StatusLineMonitor(paneID: UUID(), workingDirectory: nil, harness: .claude)
        var mergedCount = 0
        monitor.onPRMerged = { _, _ in mergedCount += 1 }
        monitor.onPRReopened = {}

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged"))
        XCTAssertEqual(mergedCount, 1)

        monitor.simulatePRUpdateForTesting(makePRJSON(state: "open"))
        monitor.simulatePRUpdateForTesting(makePRJSON(state: "merged"))
        XCTAssertEqual(mergedCount, 2, "Merged notification should re-arm after a non-merged poll")
    }

    func testPaneStaysMergedAfterClearNotification() {
        let state = AppState()
        let tab = Tab(name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "feature")
        state.tabs.append(tab)

        state.addPRMergedNotification(
            paneID: pane.id, paneName: "feature", tabID: tab.id, tabName: "T",
            prNumber: 7, prTitle: "Fix"
        )
        state.clearNotification(paneID: pane.id)

        XCTAssertTrue(pane.isMerged, "isMerged must survive notification clearance")
        XCTAssertTrue(state.notifications.isEmpty, "notification should be cleared")
    }

    private func makePRJSON(state: String, number: Int = 1, title: String = "PR") -> Data {
        Data(
            """
            {"number":\(number),"title":"\(title)","state":"\(state)","url":"https://github.com/owner/repo/pull/\(number)"}
            """.utf8)
    }
}
