import Foundation

enum PersistenceHelpers {
    nonisolated(unsafe) static var overrideAppSupportSubdirectory: String?

    static var appSupportSubdirectory: String {
        if let override = overrideAppSupportSubdirectory {
            return override
        }
        if let run = RecursiveDevelopmentRunContext.validateProcessLaunch() {
            return run.persistenceSubdirectory
        }
        #if DEV_BUILD
        return "agent-session-manager.dev"
        #else
        if let bundleID = Bundle.main.bundleIdentifier {
            return String(bundleID.split(separator: ".").last ?? "agent-session-manager")
        }
        return "agent-session-manager"
        #endif
    }
}
