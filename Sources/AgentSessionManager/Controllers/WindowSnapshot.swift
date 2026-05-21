import AppKit
import Foundation

/// Diagnostic-only helper. Emits a TracingService span recording the current state of every
/// `NSWindow` in `NSApp.windows` so we can reconstruct the AppKit window-list timeline
/// during a notification click and identify when/where a duplicate main window is born.
///
/// All output is gated on `#if DEV_BUILD` so production builds emit nothing.
@MainActor
enum WindowSnapshot {
    static let category = "duplicate_window_diagnosis"

    /// Records an instant span tagged for the duplicate-window investigation.
    /// `event` is the timeline label (e.g. `"notification.click.handler_entered"`).
    /// `extra` is merged into the span attributes after the standard fields.
    static func record(event: String, extra: [String: String] = [:]) {
        #if DEV_BUILD
        var attributes: [String: String] = [
            "category": category,
            "event": event,
            "windowCount": String(NSApp.windows.count),
            "mainAppWindowCount": String(
                NSApp.windows.filter { $0.title == AppDelegate.windowTitle && !($0 is NSPanel) }.count
            ),
            "windows": serializeWindows(NSApp.windows),
        ]
        if let key = NSApp.keyWindow {
            attributes["keyWindowID"] = identityHash(key)
        }
        if let main = NSApp.mainWindow {
            attributes["mainWindowID"] = identityHash(main)
        }
        for (k, v) in extra {
            attributes[k] = v
        }
        TracingService.shared.record("window.snapshot", attributes: attributes)
        #endif
    }

    #if DEV_BUILD
    private static func serializeWindows(_ windows: [NSWindow]) -> String {
        let items = windows.map(serializeWindow)
        guard let data = try? JSONSerialization.data(withJSONObject: items, options: []) else {
            return "[]"
        }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func serializeWindow(_ window: NSWindow) -> [String: Any] {
        [
            "id": identityHash(window),
            "title": window.title,
            "isVisible": window.isVisible,
            "isMiniaturized": window.isMiniaturized,
            "isKey": window.isKeyWindow,
            "isMain": window.isMainWindow,
            "isPanel": window is NSPanel,
            "occlusion": occlusionDescription(window.occlusionState),
            "controllerType": window.windowController.map { String(describing: type(of: $0)) } ?? "nil",
            "windowClass": String(describing: type(of: window)),
            "identifier": window.identifier?.rawValue ?? "",
            "level": window.level.rawValue,
            "frame": NSStringFromRect(window.frame),
        ]
    }

    private static func identityHash(_ window: NSWindow) -> String {
        String(ObjectIdentifier(window).hashValue, radix: 16)
    }

    private static func occlusionDescription(_ state: NSWindow.OcclusionState) -> String {
        state.contains(.visible) ? "visible" : "hidden"
    }
    #endif
}
