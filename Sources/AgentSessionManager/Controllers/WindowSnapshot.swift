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
        let windowItems: [[String: Any]] = NSApp.windows.map { window in
            [
                "id": identityHash(window),
                "title": window.title,
                "isVisible": window.isVisible,
                "isMiniaturized": window.isMiniaturized,
                "isKey": window.isKeyWindow,
                "isMain": window.isMainWindow,
                "isPanel": window is NSPanel,
                "occlusion": window.occlusionState.contains(.visible) ? "visible" : "hidden",
                "controllerType": window.windowController.map { String(describing: type(of: $0)) } ?? "nil",
                "windowClass": String(describing: type(of: window)),
                "identifier": window.identifier?.rawValue ?? "",
                "level": window.level.rawValue,
                "frame": NSStringFromRect(window.frame),
            ]
        }
        let serializedWindows =
            (try? JSONSerialization.data(withJSONObject: windowItems))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        var attributes: [String: String] = [
            "category": category,
            "event": event,
            "windowCount": String(NSApp.windows.count),
            "mainAppWindowCount": String(
                NSApp.windows.filter { $0.title == AppDelegate.windowTitle && !($0 is NSPanel) }.count
            ),
            "windows": serializedWindows,
        ]
        if let key = NSApp.keyWindow {
            attributes["keyWindowID"] = identityHash(key)
        }
        if let main = NSApp.mainWindow {
            attributes["mainWindowID"] = identityHash(main)
        }
        for (key, value) in extra {
            attributes[key] = value
        }
        TracingService.shared.record("window.snapshot", attributes: attributes)
        #endif
    }

    #if DEV_BUILD
    private static func identityHash(_ window: NSWindow) -> String {
        String(ObjectIdentifier(window).hashValue, radix: 16)
    }

    #endif
}
