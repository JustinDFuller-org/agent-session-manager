import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        UNUserNotificationCenter.current().delegate = MacNotificationCoordinator.shared
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.windows.first { !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
        return false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
}
