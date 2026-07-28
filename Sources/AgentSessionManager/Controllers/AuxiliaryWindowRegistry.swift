import AppKit
import Foundation

enum AuxiliaryWindowRegistry {
    static let auxiliaryWindowIDsByTitle: [String: String] = [
        "Trace Dashboard": "trace-dashboard",
        "Invariant Dashboard": "invariant-dashboard",
    ]

    @discardableResult
    static func check(openTitles: [String], requestedIDs: Set<String>) -> Bool {
        var passed = true
        for title in openTitles {
            guard let id = auxiliaryWindowIDsByTitle[title] else { continue }
            let requested = InvariantReporter.shared.check(
                .appLaunchAuxiliaryWindowsClosed,
                requestedIDs.contains(id),
                context: ["window.title": title, "window.id": id]
            )
            if !requested { passed = false }
        }
        return passed
    }
}

extension AuxiliaryWindowRegistry {
    @MainActor
    private static var requestedWindowIDs: Set<String> = []

    @MainActor
    static func recordExplicitOpen(id: String) {
        requestedWindowIDs.insert(id)
    }

    @MainActor
    @discardableResult
    static func checkOpenWindows() -> Bool {
        check(openTitles: NSApp.windows.map(\.title), requestedIDs: requestedWindowIDs)
    }
}
