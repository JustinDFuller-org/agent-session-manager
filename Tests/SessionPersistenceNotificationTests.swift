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
            timestamp: ts,
            kind: .terminalBell,
            reason: "Permission needed"
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

    func testLegacyPendingNotificationReasonDefaultsNil() throws {
        let data = Data(
            """
            {
              "notificationID":"00000000-0000-0000-0000-000000000001",
              "paneID":"00000000-0000-0000-0000-000000000002",
              "paneName":"p",
              "tabID":"00000000-0000-0000-0000-000000000003",
              "tabName":"t",
              "isPriority":false,
              "timestamp":0
            }
            """.utf8)
        let decoded = try JSONDecoder().decode(PersistedPaneNotification.self, from: data)
        XCTAssertNil(decoded.reason)
    }

    func testUnknownNotificationKindFallsBackToTerminalBell() throws {
        let data = Data(
            """
            {
              "notificationID":"00000000-0000-0000-0000-000000000001",
              "paneID":"00000000-0000-0000-0000-000000000002",
              "paneName":"p",
              "tabID":"00000000-0000-0000-0000-000000000003",
              "tabName":"t",
              "isPriority":false,
              "timestamp":0,
              "kind":"future_kind"
            }
            """.utf8)
        let decoded = try JSONDecoder().decode(PersistedPaneNotification.self, from: data)
        XCTAssertEqual(decoded.kind, .terminalBell)
    }

    func testPersistedNotificationReasonRoundTripsThroughAppState() {
        let state = AppState()
        state.addNotification(
            paneID: UUID(), paneName: "p", tabID: UUID(), tabName: "t", isPriority: false,
            event: PaneAttentionEvent(source: .claudePermissionRequest, reason: "Permission needed for Bash")
        )
        let session = SessionPersistence.makePersistedSession(appState: state)
        XCTAssertEqual(session.pendingNotifications.first?.reason, "Permission needed for Bash")
    }

    func testRestoreUsesPersistedTabAndPaneIDs() {
        let tabID = UUID()
        let paneID = UUID()
        let tab = Tab(id: tabID, name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "P", id: paneID)
        XCTAssertEqual(tab.id, tabID)
        XCTAssertEqual(pane.id, paneID)
    }

    func testPersistedDirectoryURLPreservesSpaces() {
        let path = "/tmp/Agent Session Manager/project"
        XCTAssertEqual(SessionPersistence.persistedDirectoryURL(for: path)?.path, path)
    }

    func testPersistedDirectoryURLRejectsEmptyPath() {
        XCTAssertNil(SessionPersistence.persistedDirectoryURL(for: ""))
    }

    func testProfileIDPreservedAfterAddPane() {
        let profileID = UUID()
        let tab = Tab(id: UUID(), name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "P", profileID: profileID)
        XCTAssertEqual(pane.profileID, profileID)
    }

    func testIsMergedPersistedAndRestored() throws {
        let persisted = PersistedPane(
            id: UUID(), name: "p", harness: .claude, isPriority: false, isMerged: true,
            worktreeDirectory: nil, worktreeIsManaged: false
        )
        let data = try JSONEncoder().encode(persisted)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: data)
        XCTAssertTrue(decoded.isMerged)
    }

    func testLegacyPaneDefaultsIsMergedFalse() throws {
        let json = Data(
            """
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "name": "p",
              "harness": "claude",
              "isPriority": false,
              "worktreeIsManaged": false
            }
            """.utf8)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertFalse(decoded.isMerged)
    }

    func testExtraArgsPreservedInPane() {
        let tab = Tab(id: UUID(), name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "P", extraArgs: ["--model", "opus"])
        XCTAssertEqual(pane.extraArgs, ["--model", "opus"])
    }

    func testOpenCodeSessionIDPreservedInPane() {
        let tab = Tab(id: UUID(), name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = tab.addPane(name: "P", harness: .opencode)
        pane.opencodeSessionID = "ses_abc"
        XCTAssertEqual(pane.opencodeSessionID, "ses_abc")
    }

    func testOpenCodeSessionIDIncludedInPersistedSession() {
        let appState = AppState()
        let tab = Tab(name: "T", directory: URL(filePath: "/tmp"))
        let pane = Pane(name: "P", tab: tab, harness: .opencode)
        pane.opencodeSessionID = "ses_xyz"
        pane.worktreeDirectory = URL(filePath: "/tmp")
        tab.panes.append(pane)
        appState.tabs.append(tab)

        let session = SessionPersistence.makePersistedSession(appState: appState)
        XCTAssertEqual(session.tabs.first?.panes.first?.opencodeSessionID, "ses_xyz")
    }

    func testExtraArgsRoundTripInPersistedPane() throws {
        let persisted = PersistedPane(
            id: UUID(), name: "p", harness: .claude,
            extraArgs: ["--model", "claude-opus-4-5"]
        )
        let data = try JSONEncoder().encode(persisted)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: data)
        XCTAssertEqual(decoded.extraArgs, ["--model", "claude-opus-4-5"])
    }

    func testLegacyPaneDefaultsExtraArgsEmpty() throws {
        let json = Data(
            """
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "name": "p",
              "harness": "claude",
              "isPriority": false,
              "worktreeIsManaged": false
            }
            """.utf8)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertEqual(decoded.extraArgs, [])
    }

    func testRestoreCombinesExtraArgsWithContinue() throws {
        let pane = PersistedPane(
            id: UUID(), name: "p", harness: .claude,
            extraArgs: ["--model", "claude-opus-4-5"]
        )
        var extraArgs = pane.extraArgs
        let continueOnRestart = true
        if pane.harness == .claude && continueOnRestart && !extraArgs.contains("--continue") {
            extraArgs.append("--continue")
        }
        XCTAssertEqual(extraArgs, ["--model", "claude-opus-4-5", "--continue"])
    }

    func testOpenCodeSessionIDRoundTripInPersistedPane() throws {
        let persisted = PersistedPane(
            id: UUID(), name: "p", harness: .opencode,
            opencodeSessionID: "ses_abc123"
        )
        let data = try JSONEncoder().encode(persisted)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: data)
        XCTAssertEqual(decoded.opencodeSessionID, "ses_abc123")
    }

    func testLegacyPaneDefaultsOpenCodeSessionIDNil() throws {
        let json = Data(
            """
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "name": "p",
              "harness": "opencode",
              "isPriority": false,
              "worktreeIsManaged": false
            }
            """.utf8)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: json)
        XCTAssertNil(decoded.opencodeSessionID)
    }

    func testRestoreCombinesOpenCodeSessionIdWhenContinueOnRestartEnabled() {
        let pane = PersistedPane(
            id: UUID(), name: "p", harness: .opencode,
            extraArgs: ["--model", "test"],
            opencodeSessionID: "ses_resume"
        )
        var extraArgs = pane.extraArgs
        var resumeOpencodeSessionID: String?
        let continueOnRestart = true
        if pane.harness == .opencode && continueOnRestart {
            if let id = pane.opencodeSessionID, !extraArgs.contains("--session") {
                resumeOpencodeSessionID = id
            } else if !extraArgs.contains("--continue") {
                extraArgs.append("--continue")
            }
        }
        XCTAssertEqual(resumeOpencodeSessionID, "ses_resume")
        XCTAssertEqual(extraArgs, ["--model", "test"])
    }

    func testRestoreFallsBackToOpenCodeContinueWhenSessionIdMissing() {
        let pane = PersistedPane(
            id: UUID(), name: "p", harness: .opencode,
            extraArgs: ["--model", "test"]
        )
        var extraArgs = pane.extraArgs
        var resumeOpencodeSessionID: String?
        let continueOnRestart = true
        if pane.harness == .opencode && continueOnRestart {
            if let id = pane.opencodeSessionID, !extraArgs.contains("--session") {
                resumeOpencodeSessionID = id
            } else if !extraArgs.contains("--continue") {
                extraArgs.append("--continue")
            }
        }
        XCTAssertNil(resumeOpencodeSessionID)
        XCTAssertEqual(extraArgs, ["--model", "test", "--continue"])
    }

    func testRestoreOpenCodeNoResumeWhenContinueOnRestartDisabled() {
        let pane = PersistedPane(
            id: UUID(), name: "p", harness: .opencode,
            extraArgs: ["--model", "test"],
            opencodeSessionID: "ses_resume"
        )
        var extraArgs = pane.extraArgs
        var resumeOpencodeSessionID: String?
        let continueOnRestart = false
        if pane.harness == .opencode && continueOnRestart {
            if let id = pane.opencodeSessionID, !extraArgs.contains("--session") {
                resumeOpencodeSessionID = id
            } else if !extraArgs.contains("--continue") {
                extraArgs.append("--continue")
            }
        }
        XCTAssertNil(resumeOpencodeSessionID)
        XCTAssertEqual(extraArgs, ["--model", "test"])
    }

    func testOpenCodeSessionBoundUpdatesPane() async {
        let appState = AppState()
        let tab = Tab(id: UUID(), name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = Pane(name: "P", tab: tab, harness: .opencode)
        let monitor = StatusLineMonitor(
            paneID: pane.id, paneName: pane.name, workingDirectory: "/tmp",
            harness: .opencode, processStartTime: Date(), tabID: tab.id, tabName: tab.name)
        pane.installStatusLineMonitor(monitor)
        pane.bindNotifications(appState: appState, isPriority: false)

        XCTAssertNotNil(pane.tab)
        XCTAssertNotNil(pane.notificationAppState)
        XCTAssertNotNil(pane.statusLineMonitor?.onOpencodeSessionBound)

        pane.opencodeRaceLossRestarted = true
        pane.statusLineMonitor?.onOpencodeSessionBound?("ses_from_monitor")
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(pane.opencodeSessionID, "ses_from_monitor")
        XCTAssertFalse(pane.opencodeRaceLossRestarted)
    }

    func testOpencodePortRaceLossRestartsPaneWithFreshPortOnce() async {
        let appState = AppState()
        let tab = Tab(id: UUID(), name: "T", directory: URL(fileURLWithPath: "/tmp"))
        let pane = Pane(name: "P", tab: tab, harness: .opencode)
        let controller = TerminalController()
        controller.pendingDirectory = "/tmp"
        controller.pendingCommandArgs = ["opencode"]
        pane.installTerminalController(controller)
        tab.panes.append(pane)

        let originalPort = 12345
        pane.opencodePort = originalPort
        let monitor = StatusLineMonitor(
            paneID: pane.id, paneName: pane.name, workingDirectory: "/tmp",
            harness: .opencode, processStartTime: Date(), tabID: tab.id, tabName: tab.name,
            opencodePort: originalPort)
        pane.installStatusLineMonitor(monitor)
        pane.bindNotifications(appState: appState, isPriority: false)

        let originalToken = pane.restartToken
        pane.statusLineMonitor?.onOpencodePortRaceLost?()
        try? await Task.sleep(for: .milliseconds(100))

        let restartedPort = pane.opencodePort
        let restartedToken = pane.restartToken
        XCTAssertNotNil(restartedPort)
        XCTAssertNotEqual(restartedPort, originalPort)
        XCTAssertNotEqual(restartedToken, originalToken)
        XCTAssertTrue(pane.opencodeRaceLossRestarted)

        pane.statusLineMonitor?.onOpencodePortRaceLost?()
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(pane.opencodePort, restartedPort)
        XCTAssertEqual(pane.restartToken, restartedToken)

        pane.removeStatusLineMonitor()
        pane.terminalController?.terminate()
    }

    func testBaseBranchOverrideRoundTripsInPersistedTab() throws {
        let id = UUID()
        let tab = PersistedTab(id: id, name: "T", directory: "/tmp", baseBranchOverride: "qa", panes: [])
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(PersistedTab.self, from: data)
        XCTAssertEqual(decoded.baseBranchOverride, "qa")
    }

    func testBaseBranchOverrideNilRoundTrips() throws {
        let id = UUID()
        let tab = PersistedTab(id: id, name: "T", directory: "/tmp", panes: [])
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(PersistedTab.self, from: data)
        XCTAssertNil(decoded.baseBranchOverride)
    }

    func testLegacyTabWithoutBaseBranchOverrideDecodesNil() throws {
        let json = Data(
            """
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "name": "T",
              "directory": "/tmp",
              "panes": []
            }
            """.utf8)
        let decoded = try JSONDecoder().decode(PersistedTab.self, from: json)
        XCTAssertNil(decoded.baseBranchOverride)
    }
}
