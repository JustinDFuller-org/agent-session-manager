import AppKit
import Foundation
import SwiftUI

enum AuxiliaryWindow: String, CaseIterable {
    case traceDashboard = "trace-dashboard"
    case invariantDashboard = "invariant-dashboard"

    var title: String {
        switch self {
        case .traceDashboard: "Trace Dashboard"
        case .invariantDashboard: "Invariant Dashboard"
        }
    }
}

enum AuxiliaryWindowRegistry {
    static let auxiliaryWindowIDsByTitle: [String: String] = Dictionary(
        uniqueKeysWithValues: AuxiliaryWindow.allCases.map { ($0.title, $0.rawValue) }
    )

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
    static func open(_ window: AuxiliaryWindow, using openWindow: OpenWindowAction) {
        recordExplicitOpen(id: window.rawValue)
        openWindow(id: window.rawValue)
    }

    @MainActor
    static func recordExplicitOpen(id: String) {
        requestedWindowIDs.insert(id)
    }

    @MainActor
    static func resetForTesting() {
        requestedWindowIDs = []
    }

    @MainActor
    @discardableResult
    static func checkOpenWindows() -> Bool {
        let openTitles = NSApp?.windows.filter(\.isVisible).map(\.title) ?? []
        TracingService.shared.record(
            "app.launch.auxiliary_windows_checked",
            attributes: [
                "window.titles": openTitles.joined(separator: ","),
                "window.requested_ids": requestedWindowIDs.sorted().joined(separator: ","),
            ]
        )
        return check(openTitles: openTitles, requestedIDs: requestedWindowIDs)
    }
}
