import AppKit
import UniformTypeIdentifiers
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

    /// Set while handling a banner click so `applicationShouldHandleReopen` can avoid redundant work.
    private(set) var isHandlingNotificationResponse = false

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

    /// Options for notification image attachments (PNG type hint for UserNotifications).
    nonisolated static let notificationAttachmentOptions: [AnyHashable: Any] = [
        UNNotificationAttachmentOptionsTypeHintKey: UTType.png.identifier,
    ]

    /// Loads the app icon directly from the bundle's compiled .icns file so the correct icon is
    /// used for both prod (AppIcon) and dev (AppIcon-Dev) builds. Falls back to
    /// `NSApp.applicationIconImage` when loading from `Bundle.main` and no .icns is found.
    static func bundleAppIcon(in bundle: Bundle = .main) -> NSImage? {
        let name = (bundle.infoDictionary?["CFBundleIconFile"] as? String) ?? "AppIcon"
        if let url = bundle.url(forResource: name, withExtension: "icns") {
            return NSImage(contentsOf: url)
        }
        if bundle == .main, let app = NSApp {
            return app.applicationIconImage
        }
        return nil
    }

    /// Converts an NSImage to a UNNotificationAttachment by writing a temp PNG file.
    /// The notification system copies the file on attachment creation, so the temp file is
    /// removed only after a successful attachment init. Returns nil if the image is unavailable
    /// or conversion fails.
    static func makeAttachment(from image: NSImage?) -> UNNotificationAttachment? {
        guard let image,
            let tiffData = image.tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffData),
            let pngData = bitmapRep.representation(using: .png, properties: [:])
        else { return nil }
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "agent-session-manager-notification-icon-\(UUID().uuidString).png")
        do {
            try pngData.write(to: tempURL)
            let attachment = try UNNotificationAttachment(
                identifier: "app-icon",
                url: tempURL,
                options: notificationAttachmentOptions)
            try? FileManager.default.removeItem(at: tempURL)
            return attachment
        } catch {
            return nil
        }
    }

    /// Best-effort PNG attachment for notification rich content; traces when icon or conversion fails.
    static func notificationIconAttachment() -> UNNotificationAttachment? {
        guard let image = bundleAppIcon() else {
            TracingService.shared.record(
                "notification.icon.unavailable",
                attributes: ["reason": "bundle_app_icon_nil"])
            return nil
        }
        guard let attachment = makeAttachment(from: image) else {
            TracingService.shared.record(
                "notification.icon.unavailable",
                attributes: ["reason": "attachment_creation_failed"])
            return nil
        }
        return attachment
    }

    func requestAuthorizationIfNeeded() async {
        guard !AgentSessionManagerApp.isUITesting else { return }
        guard let appSettings = self.appSettings else { return }
        guard appSettings.isMacOSBannerNotificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return
        }
        TracingService.shared.record(
            "notification.auth.requested",
            attributes: ["result": granted ? "authorized" : "denied"])
    }

    func postPaneAttentionIfNeeded(
        paneID: UUID,
        paneName: String,
        tabID: UUID,
        tabName: String
    ) {
        guard let appSettings = self.appSettings else { return }
        guard appSettings.isMacOSBannerNotificationsEnabled else { return }
        guard !AgentSessionManagerApp.isUITesting else { return }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            guard settings.alertSetting == .enabled else { return }
            let content = UNMutableNotificationContent()
            content.title = "Agent Session Manager"
            content.subtitle = paneName
            content.body = "Tab \"\(tabName)\" needs attention."
            content.sound = .default
            content.userInfo = [
                MacNotificationUserInfoKey.paneID: paneID.uuidString,
                MacNotificationUserInfoKey.tabID: tabID.uuidString,
            ]
            if let attachment = Self.notificationIconAttachment() {
                content.attachments = [attachment]
            }
            let identifier = "pane-\(paneID.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            do {
                try await center.add(request)
                TracingService.shared.record(
                    "notification.pane_attention.posted",
                    attributes: [
                        "pane.name": paneName,
                        "title": "Agent Session Manager",
                    ])
            } catch {
                TracingService.shared.record(
                    "notification.pane_attention.skipped",
                    attributes: [
                        "pane.name": paneName,
                        "reason": "schedule_error",
                    ])
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
            if let attachment = Self.notificationIconAttachment() {
                content.attachments = [attachment]
            }
            let identifier = "pr-merged-\(paneID.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            do {
                try await center.add(request)
                TracingService.shared.record(
                    "notification.pr_merged.posted",
                    attributes: [
                        "pane.name": paneName,
                        "pr.title": prTitle,
                    ])
            } catch {
            }
        }
    }

    func removeDeliveredNotifications(forPaneID paneID: UUID) {
        guard appSettings != nil else { return }
        guard !AgentSessionManagerApp.isUITesting else { return }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            center.removeDeliveredNotifications(withIdentifiers: [
                "pane-\(paneID.uuidString)",
                "pr-merged-\(paneID.uuidString)",
            ])
        }
    }

    func removeAllDeliveredNotificationsIfStickyEnabled() {
        guard appSettings?.isStickyNotificationsEnabled == true else { return }
        guard !AgentSessionManagerApp.isUITesting else { return }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            center.removeAllDeliveredNotifications()
        }
    }

    /// Navigates to the pane identified by `paneIDStr`/`tabIDStr` and, for PR merged
    /// notifications, additionally posts `prMergedActionRequested` so the alert appears.
    /// Extracted for testability — does not call `NSApp.activate`.
    func handleNotificationNavigation(paneIDStr: String, tabIDStr: String, kind: String?) {
        guard
            let paneID = UUID(uuidString: paneIDStr),
            let tabID = UUID(uuidString: tabIDStr),
            let state = appState
        else { return }
        state.focusPane(tabID: tabID, paneID: paneID)
        if kind == NotificationKind.prMerged.rawValue {
            NotificationCenter.default.post(
                name: .prMergedActionRequested,
                object: nil,
                userInfo: ["paneID": paneIDStr, "tabID": tabIDStr]
            )
        }
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        guard
            let paneIDStr = userInfo[MacNotificationUserInfoKey.paneID] as? String,
            let tabIDStr = userInfo[MacNotificationUserInfoKey.tabID] as? String
        else { return }
        let kind = userInfo[MacNotificationUserInfoKey.notificationKind] as? String
        isHandlingNotificationResponse = true
        defer { isHandlingNotificationResponse = false }
        handleNotificationNavigation(paneIDStr: paneIDStr, tabIDStr: tabIDStr, kind: kind)
        MainWindowController.activateApplicationForUserAttention()
        MainWindowController.focusMainWindowAndDedupe()
    }

    /// UI tests: simulates a banner click without Notification Center (focus + dedupe only).
    func simulateBannerClickForUITesting(paneID: UUID, tabID: UUID, kind: String? = nil) {
        guard AgentSessionManagerApp.isUITesting else { return }
        isHandlingNotificationResponse = true
        defer { isHandlingNotificationResponse = false }
        handleNotificationNavigation(
            paneIDStr: paneID.uuidString,
            tabIDStr: tabID.uuidString,
            kind: kind
        )
        MainWindowController.activateApplicationForUserAttention()
        MainWindowController.focusMainWindowAndDedupe()
    }

    /// UI tests: applies the legacy `NSApp.activate` path that could spawn a duplicate main window, then dedupes.
    func simulateLegacyNotificationActivationForUITesting() {
        guard AgentSessionManagerApp.isUITesting else { return }
        isHandlingNotificationResponse = true
        defer { isHandlingNotificationResponse = false }
        NSApp.activate(ignoringOtherApps: true)
        MainWindowController.focusMainWindowAndDedupe()
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
