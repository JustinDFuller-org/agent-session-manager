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
}
