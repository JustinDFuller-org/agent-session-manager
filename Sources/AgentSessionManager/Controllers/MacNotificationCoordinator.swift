import AppKit
import UserNotifications

enum MacNotificationUserInfoKey {
    static let paneID = "paneID"
    static let tabID = "tabID"
    static let notificationKind = "notificationKind"
}

enum MacNotificationFailureSite: String {
    case requestAuthorization
    case scheduleLocalNotification
}

/// Posts macOS banner notifications when a pane rings the terminal bell (with user permission).
/// Banners are presented even while Agent Session Manager is frontmost so attention is visible on the desktop.
@MainActor
final class MacNotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = MacNotificationCoordinator()

    private weak var appState: AppState?
    private weak var appSettings: AppSettings?

    /// Logged once per process when banners are on but UN authorization is denied.
    private static var hasLoggedDeniedBannerHint = false

    /// Maps `NSError` from UserNotifications APIs for debug logs and unit tests.
    nonisolated static func describeUserNotificationsNSError(_ error: Error) -> String {
        let ns = error as NSError
        var suffix = ""
        if ns.domain == UNError.errorDomain {
            if ns.code == UNError.Code.notificationsNotAllowed.rawValue {
                suffix =
                    " unError=notificationsNotAllowed (see System Settings → Notifications for this app’s bundle ID; `make app` builds are ad-hoc signed)"
            } else if let code = UNError.Code(rawValue: ns.code) {
                suffix = " unError=\(String(describing: code))"
            } else {
                suffix = " unError=raw(\(ns.code))"
            }
        }
        return
            "domain=\(ns.domain) code=\(ns.code)\(suffix) description=\(ns.localizedDescription) userInfo=\(ns.userInfo as NSDictionary)"
    }

    func bind(appState: AppState, appSettings: AppSettings) {
        self.appState = appState
        self.appSettings = appSettings
    }

    func requestAuthorizationIfNeeded() async {
        guard !AgentSessionManagerApp.isUITesting else {
            await MainActor.run {
                if DebugLogger.shared.isEnabled {
                    DebugLogger.shared.log("[banner] requestAuthorization skipped (UI testing)")
                }
            }
            return
        }
        guard let appSettings = self.appSettings else {
            await MainActor.run {
                if DebugLogger.shared.isEnabled {
                    DebugLogger.shared.log(
                        "[banner] requestAuthorization skipped (coordinator not bound yet; banner flow requires bind before ContentView loads)"
                    )
                }
            }
            return
        }
        guard appSettings.isMacOSBannerNotificationsEnabled else {
            await MainActor.run {
                if DebugLogger.shared.isEnabled {
                    DebugLogger.shared.log(
                        "[banner] requestAuthorization skipped (macOS banner notifications off in settings)")
                }
            }
            return
        }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            DebugLogger.shared.log(
                "[banner] notification settings snapshot authorization=\(String(describing: settings.authorizationStatus)) macOSBannersEnabled=\(appSettings.isMacOSBannerNotificationsEnabled) willRequest=\(settings.authorizationStatus == .notDetermined)"
            )
            if settings.authorizationStatus == .denied, DebugLogger.shared.isEnabled,
                !Self.hasLoggedDeniedBannerHint
            {
                Self.hasLoggedDeniedBannerHint = true
                DebugLogger.shared.log(
                    "[banner] authorization denied for banners — enable Agent Session Manager in System Settings → Notifications (in-app sidebar still works without this)"
                )
            }
        }
        guard settings.authorizationStatus == .notDetermined else { return }
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            await MainActor.run {
                DebugLogger.shared.log(
                    "[banner] failureSite=\(MacNotificationFailureSite.requestAuthorization.rawValue) \(Self.describeUserNotificationsNSError(error))"
                )
            }
            return
        }
        await MainActor.run {
            DebugLogger.shared.log("[banner] requestAuthorization finished granted=\(granted)")
        }
    }

    func postPaneAttentionIfNeeded(
        paneID: UUID,
        paneName: String,
        tabID: UUID,
        tabName: String
    ) {
        DebugLogger.shared.log(
            "[banner] postPaneAttentionIfNeeded begin tab=\(tabName) pane=\(paneName) tabID=\(tabID.uuidString) bannersEnabled=\(appSettings?.isMacOSBannerNotificationsEnabled ?? false)",
            paneID: paneID,
            tabName: tabName,
            paneName: paneName
        )
        guard let appSettings = self.appSettings else {
            DebugLogger.shared.log(
                "[banner] skipped coordinator not bound (no app settings)",
                paneID: paneID,
                tabName: tabName,
                paneName: paneName
            )
            return
        }
        guard appSettings.isMacOSBannerNotificationsEnabled else {
            DebugLogger.shared.log(
                "[banner] skipped banner notifications disabled in settings",
                paneID: paneID,
                tabName: tabName,
                paneName: paneName
            )
            return
        }
        guard !AgentSessionManagerApp.isUITesting else {
            DebugLogger.shared.log("[banner] skipped UI testing", paneID: paneID, tabName: tabName, paneName: paneName)
            return
        }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                DebugLogger.shared.log(
                    "[banner] skipped authorization=\(String(describing: settings.authorizationStatus))",
                    paneID: paneID,
                    tabName: tabName,
                    paneName: paneName
                )
                return
            }
            guard settings.alertSetting == .enabled else {
                DebugLogger.shared.log(
                    "[banner] skipped alertSetting=\(String(describing: settings.alertSetting)) (allow banners or alerts for this app in System Settings → Notifications)",
                    paneID: paneID,
                    tabName: tabName,
                    paneName: paneName
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
                    paneID: paneID,
                    tabName: tabName,
                    paneName: paneName
                )
            } catch {
                DebugLogger.shared.log(
                    "[banner] failureSite=\(MacNotificationFailureSite.scheduleLocalNotification.rawValue) \(Self.describeUserNotificationsNSError(error))",
                    paneID: paneID,
                    tabName: tabName,
                    paneName: paneName
                )
            }
        }
    }

    func postPRMergedBannerIfNeeded(
        paneID: UUID,
        paneName: String,
        tabID: UUID,
        tabName: String,
        prNumber: Int,
        prTitle: String
    ) {
        guard let appSettings = self.appSettings, appSettings.isMacOSBannerNotificationsEnabled else { return }
        guard !AgentSessionManagerApp.isUITesting else { return }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            guard settings.alertSetting == .enabled else { return }
            let content = UNMutableNotificationContent()
            content.title = "PR Merged"
            content.subtitle = paneName
            content.body = "PR #\(prNumber): \(prTitle)"
            content.sound = .default
            content.userInfo = [
                MacNotificationUserInfoKey.paneID: paneID.uuidString,
                MacNotificationUserInfoKey.tabID: tabID.uuidString,
                MacNotificationUserInfoKey.notificationKind: NotificationKind.prMerged.rawValue,
            ]
            let identifier = "pr-merged-\(paneID.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            do {
                try await center.add(request)
                DebugLogger.shared.log(
                    "[banner] postPRMergedBanner succeeded identifier=\(identifier)",
                    paneID: paneID,
                    tabName: tabName,
                    paneName: paneName
                )
            } catch {
                DebugLogger.shared.log(
                    "[banner] postPRMergedBanner failed \(Self.describeUserNotificationsNSError(error))",
                    paneID: paneID,
                    tabName: tabName,
                    paneName: paneName
                )
            }
        }
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        guard
            let paneIDStr = userInfo[MacNotificationUserInfoKey.paneID] as? String,
            let tabIDStr = userInfo[MacNotificationUserInfoKey.tabID] as? String,
            let state = appState
        else { return }
        let kind = userInfo[MacNotificationUserInfoKey.notificationKind] as? String
        if kind == NotificationKind.prMerged.rawValue {
            NotificationCenter.default.post(
                name: .prMergedActionRequested,
                object: nil,
                userInfo: ["paneID": paneIDStr, "tabID": tabIDStr]
            )
            NSApp.activate(ignoringOtherApps: true)
        } else {
            guard
                let paneID = UUID(uuidString: paneIDStr),
                let tabID = UUID(uuidString: tabIDStr)
            else { return }
            state.focusPane(tabID: tabID, paneID: paneID)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Options passed to `willPresent` — exposed for unit tests.
    nonisolated static let willPresentPresentationOptions: UNNotificationPresentationOptions = [.banner, .sound]

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let req = notification.request
        let info = req.content.userInfo
        let keys = info.keys.map { "\($0)" }.sorted().joined(separator: ",")
        Task { @MainActor in
            DebugLogger.shared.log(
                "[banner] willPresent id=\(req.identifier) title=\(req.content.title) subtitle=\(req.content.subtitle) body=\(req.content.body) userInfoKeys=\(keys)"
            )
        }
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
