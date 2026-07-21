import Foundation
import os

/// Unified-logging façade (`os.Logger`). Complements ``TracingService``'s OTel spans:
/// spans are gated behind Debug Mode and written to per-pane JSONL, while these logs are
/// always-on and surface in Console.app / `log stream` regardless of Debug Mode.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.justinfuller.agent-session-manager"

    /// Logging categories, one per `os.Logger`. Mirrors the span-name prefixes already in use
    /// across the codebase (see ``category(forSpanName:)``).
    enum Category: String, CaseIterable, Equatable, Sendable {
        case terminal
        case pane
        case tab
        case pr
        case statusline
        case notification
        case session
        case invariant
        case app
    }

    static let terminal = Logger(subsystem: subsystem, category: Category.terminal.rawValue)
    static let pane = Logger(subsystem: subsystem, category: Category.pane.rawValue)
    static let tab = Logger(subsystem: subsystem, category: Category.tab.rawValue)
    static let pr = Logger(subsystem: subsystem, category: Category.pr.rawValue)
    static let statusline = Logger(subsystem: subsystem, category: Category.statusline.rawValue)
    static let notification = Logger(subsystem: subsystem, category: Category.notification.rawValue)
    static let session = Logger(subsystem: subsystem, category: Category.session.rawValue)
    static let invariant = Logger(subsystem: subsystem, category: Category.invariant.rawValue)
    static let app = Logger(subsystem: subsystem, category: Category.app.rawValue)

    /// Maps a dotted span name (e.g. `"pane.created"`) to its logging category by prefix.
    /// Pure so it can be unit-tested independently of `os.Logger`; mirrors `spanColor(for:)`
    /// in `TraceDashboardView.swift`.
    static func category(forSpanName name: String) -> Category {
        let prefix = name.components(separatedBy: ".").first ?? name
        return Category(rawValue: prefix) ?? .app
    }

    /// Maps an invariant severity to the matching unified-logging level.
    static func osLogType(for severity: Invariant.Severity) -> OSLogType {
        switch severity {
        case .warning: return .default
        case .error: return .error
        }
    }

    private static func logger(for category: Category) -> Logger {
        switch category {
        case .terminal: return terminal
        case .pane: return pane
        case .tab: return tab
        case .pr: return pr
        case .statusline: return statusline
        case .notification: return notification
        case .session: return session
        case .invariant: return invariant
        case .app: return app
        }
    }

    /// Logs an event by name, routed to the appropriate category logger. The event name is
    /// public (it's a static string); attribute values default to private since they may
    /// contain filesystem paths, git arguments, or error text.
    static func log(_ name: String, level: OSLogType = .debug, attributes: [String: String] = [:]) {
        let logger = logger(for: category(forSpanName: name))
        guard !attributes.isEmpty else {
            logger.log(level: level, "\(name, privacy: .public)")
            return
        }
        let attrs = attributes.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        logger.log(level: level, "\(name, privacy: .public) \(attrs, privacy: .private)")
    }
}
