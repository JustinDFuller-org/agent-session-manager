import AppKit

/// Identifies and manages the single main application window (excludes Settings and panels).
@MainActor
enum MainWindowController {
    static let productionTitle = "Agent Session Manager"
    static let devTitle = "Agent Session Manager (Dev)"

    /// Window titles for the main scene in production and dev builds.
    static var mainWindowTitles: Set<String> {
        [productionTitle, devTitle]
    }

    static func isMainAppWindow(_ window: NSWindow) -> Bool {
        guard !(window is NSPanel) else { return false }
        return mainWindowTitles.contains(window.title)
    }

    static func mainAppWindows() -> [NSWindow] {
        NSApp.windows.filter(isMainAppWindow)
    }

    static func preferredMainWindow() -> NSWindow? {
        if let key = NSApp.keyWindow, isMainAppWindow(key) {
            return key
        }
        if let main = NSApp.mainWindow, isMainAppWindow(main) {
            return main
        }
        return mainAppWindows().first
    }

    /// Brings the preferred main window forward without creating a new scene.
    @discardableResult
    static func focusMainWindow() -> NSWindow? {
        guard let window = preferredMainWindow() else { return nil }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        return window
    }

    /// Closes duplicate main windows, keeping `keeper` when provided.
    static func closeDuplicateMainWindows(keeping keeper: NSWindow? = nil) {
        let resolvedKeeper = keeper ?? preferredMainWindow()
        for window in mainAppWindows() where window !== resolvedKeeper {
            window.close()
        }
    }

    /// Focuses the main window and removes any extras (sync + deferred pass for SwiftUI late creation).
    static func focusMainWindowAndDedupe() {
        let keeper = focusMainWindow()
        closeDuplicateMainWindows(keeping: keeper)
        scheduleDeferredDedupe()
    }

    static func scheduleDeferredDedupe() {
        DispatchQueue.main.async {
            closeDuplicateMainWindows(keeping: preferredMainWindow())
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            closeDuplicateMainWindows(keeping: preferredMainWindow())
        }
    }

    /// Activates the app when needed without re-presenting the main scene if a main window already exists.
    static func activateApplicationForUserAttention() {
        if preferredMainWindow() != nil {
            if NSApp.isHidden {
                NSApp.unhide(nil)
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
