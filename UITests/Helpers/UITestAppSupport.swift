import Foundation

enum UITestAppSupport {
    static var directory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEV_BUILD
        return base.appending(path: "agent-session-manager.dev")
        #else
        return base.appending(path: "agent-session-manager")
        #endif
    }
}
