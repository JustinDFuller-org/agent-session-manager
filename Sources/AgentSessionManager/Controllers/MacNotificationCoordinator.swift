import AppKit
import UserNotifications

enum MacNotificationUserInfoKey {
    static let paneID = "paneID"
    static let tabID = "tabID"
}

/// Posts macOS banner notifications when a pane rings the terminal bell (with user permission).
/// Banners are presented even while Agent Session Manager is frontmost so attention is visible on the desktop.
@MainActor
final class MacNotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = MacNotificationCoordinator()

    private weak var appState: AppState?
    private weak var appSettings: AppSettings?

    func bind(appState: AppState, appSettings: AppSettings) {
        self.appState = appState
        self.appSettings = appSettings
    }

    func requestAuthorizationIfNeeded() async {
        guard !AgentSessionManagerApp.isUITesting else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func postPaneAttentionIfNeeded(
        paneID: UUID,
        paneName: String,
        tabID: UUID,
        tabName: String
    ) {
        guard let appSettings, appSettings.isMacOSBannerNotificationsEnabled else {
            DebugLogger.shared.log(
                "[banner] skipped banner notifications disabled in settings",
                paneID: paneID
            )
            return
        }
        guard !AgentSessionManagerApp.isUITesting else {
            DebugLogger.shared.log("[banner] skipped UI testing", paneID: paneID)
            return
        }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                DebugLogger.shared.log(
                    "[banner] skipped authorization=\(String(describing: settings.authorizationStatus))",
                    paneID: paneID
                )
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Agent Session Manager"
            content.subtitle = paneName
            content.body = "Tab \"\(tabName)\" needs attention."
            content.sound = .default
            content.userInfo = [
                MacNotificationUserInfoKey.paneID: paneID.uuidString,
                MacNotificationUserInfoKey.tabID: tabID.uuidString,
            ]
            let identifier = "pane-\(paneID.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            do {
                try await center.add(request)
                DebugLogger.shared.log(
                    "[banner] UNUserNotificationCenter.add succeeded identifier=\(identifier)",
                    paneID: paneID
                )
            } catch {
                DebugLogger.shared.log(
                    "[banner] UNUserNotificationCenter.add failed: \(error.localizedDescription)",
                    paneID: paneID
                )
            }
        }
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        guard
            let paneIDStr = userInfo[MacNotificationUserInfoKey.paneID] as? String,
            let tabIDStr = userInfo[MacNotificationUserInfoKey.tabID] as? String,
            let paneID = UUID(uuidString: paneIDStr),
            let tabID = UUID(uuidString: tabIDStr),
            let state = appState
        else { return }
        state.focusPane(tabID: tabID, paneID: paneID)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Options passed to `willPresent` — exposed for unit tests.
    nonisolated static let willPresentPresentationOptions: UNNotificationPresentationOptions = [.banner, .sound]

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async {
            completionHandler(Self.willPresentPresentationOptions)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            MacNotificationCoordinator.shared.handleNotificationResponse(response)
            completionHandler()
        }
    }
}
