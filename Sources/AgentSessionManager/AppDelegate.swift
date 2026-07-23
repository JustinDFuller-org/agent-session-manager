import AppKit
import SwiftUI
import UserNotifications

private final class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let appSettings = AppSettings()
    private var mainWindow: NSWindow?
    private var mainWindowController: NSWindowController?
    private var settingsWindow: NSWindow?
    private var settingsWindowController: NSWindowController?

    #if DEV_BUILD
    private var windowLifecycleObservers: [NSObjectProtocol] = []
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        if let icon = MacNotificationCoordinator.bundleAppIcon() {
            NSApp.applicationIconImage = icon
        }
        UNUserNotificationCenter.current().delegate = MacNotificationCoordinator.shared
        MacNotificationCoordinator.shared.bind(appState: appState, appSettings: appSettings)

        let hosting = NSHostingController(
            rootView: ContentView()
                .environment(appState)
                .environment(appSettings)
                .frame(minWidth: 900, minHeight: 600)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = Self.windowTitle
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.center()
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        Theme.configure(window: window, using: Theme.mainWindowChrome)
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        mainWindow = window
        mainWindowController = controller
        Task { @MainActor in
            await AgentControlService.shared.start()
        }

        NotificationCenter.default.addObserver(
            forName: .toggleSettings, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.toggleSettings()
            }
        }

        #if DEV_BUILD
        let center = NotificationCenter.default
        let notificationsToObserve: [(Notification.Name, String)] = [
            (NSWindow.didBecomeKeyNotification, "window.did_become_key"),
            (NSWindow.didResignKeyNotification, "window.did_resign_key"),
            (NSWindow.didBecomeMainNotification, "window.did_become_main"),
            (NSWindow.didResignMainNotification, "window.did_resign_main"),
            (NSWindow.willCloseNotification, "window.will_close"),
        ]
        for (name, event) in notificationsToObserve {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { note in
                let window = note.object as? NSWindow
                let extra: [String: String] = [
                    "subjectTitle": window?.title ?? "",
                    "subjectClass": window.map { String(describing: type(of: $0)) } ?? "nil",
                    "subjectID": window.map { String(ObjectIdentifier($0).hashValue, radix: 16) }
                        ?? "nil",
                ]
                WindowSnapshot.record(event: event, extra: extra)
            }
            windowLifecycleObservers.append(token)
        }
        WindowSnapshot.record(event: "app.did_finish_launching")
        #endif
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { @MainActor in
            await AgentControlService.shared.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func focusMainWindow() {
        guard let window = mainWindow else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    func toggleSettings() {
        if settingsWindow?.isVisible == true {
            settingsWindow?.close()
            return
        }
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView()
                    .environment(appState)
                    .environment(appSettings)
                    .preferredColorScheme(.dark)
                    .tint(Theme.accent)
            )
            let window = SettingsWindow(contentViewController: hosting)
            window.title = "AgentSessionManager Settings"
            window.styleMask = [.titled, .closable]
            window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 900, height: 552))
            window.center()
            Theme.configure(window: window, using: Theme.settingsWindowChrome)
            settingsWindow = window
            settingsWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        #if DEV_BUILD
        WindowSnapshot.record(event: "app.will_become_active")
        #endif
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        #if DEV_BUILD
        WindowSnapshot.record(event: "app.did_become_active")
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        #if DEV_BUILD
        WindowSnapshot.record(
            event: "app.should_handle_reopen.entered",
            extra: [
                "hasVisibleWindows": String(flag),
                "isHandlingNotificationResponse": String(
                    MacNotificationCoordinator.shared.isHandlingNotificationResponse),
            ])
        #endif

        if MacNotificationCoordinator.shared.isHandlingNotificationResponse {
            #if DEV_BUILD
            WindowSnapshot.record(event: "app.should_handle_reopen.short_circuit_notification")
            #endif
            return false
        }
        focusMainWindow()

        #if DEV_BUILD
        WindowSnapshot.record(event: "app.should_handle_reopen.exited")
        #endif
        return false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }

    static var windowTitle: String {
        #if DEV_BUILD
        "Agent Session Manager (Dev)"
        #else
        "Agent Session Manager"
        #endif
    }
}
