import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        UNUserNotificationCenter.current().delegate = MacNotificationCoordinator.shared
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if MacNotificationCoordinator.shared.isHandlingNotificationResponse {
            return false
        }
        MainWindowController.focusMainWindow()
        MainWindowController.closeDuplicateMainWindows(keeping: MainWindowController.preferredMainWindow())
        return false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
}
