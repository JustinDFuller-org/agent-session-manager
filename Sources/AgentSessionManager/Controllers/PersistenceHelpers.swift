import Foundation

enum PersistenceHelpers {
    nonisolated(unsafe) static var overrideAppSupportSubdirectory: String?

    static var appSupportSubdirectory: String {
        if let override = overrideAppSupportSubdirectory {
            return override
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            return String(bundleID.split(separator: ".").last ?? "agent-session-manager")
        }
        return "agent-session-manager"
    }
}
