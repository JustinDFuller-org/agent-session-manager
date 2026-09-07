import AppKit
import Foundation

@MainActor
enum WindowSnapshot {
    static let category = "duplicate_window_diagnosis"

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
