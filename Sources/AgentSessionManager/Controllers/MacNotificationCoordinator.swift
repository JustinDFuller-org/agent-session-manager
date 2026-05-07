import AppKit
import UserNotifications

enum MacNotificationUserInfoKey {
    static let paneID = "paneID"
    static let tabID = "tabID"
}

/// Posts macOS banner notifications when a background pane rings the terminal bell (with user permission).
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
        guard let appSettings, appSettings.isMacOSBannerNotificationsEnabled else { return }
        guard !AgentSessionManagerApp.isUITesting else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
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
            try? await center.add(request)
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

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async {
            completionHandler(NSApp.isActive ? [] : [.banner, .sound])
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
