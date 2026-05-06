import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {
    var cliOptions: [CLIOptionConfig] = CLIOptionConfig.all
    var codexCliOptions: [CLIOptionConfig] = CLIOptionConfig.codexAll
    var statusLineConfig: StatusLineConfig = StatusLineConfig()
    var activeTools: Set<String> = [CLIType.claude.rawValue]
    var defaultBranch: String = "main"
    var isDefaultBranchEnabled: Bool = true
    var notificationSidebarSide: SidebarSide = .right
    var isPriorityNotificationsEnabled: Bool = true
    var continueOnRestart: Bool = true

    func isActive(_ tool: CLIType) -> Bool {
        activeTools.contains(tool.rawValue)
    }

    func setActive(_ tool: CLIType, _ active: Bool) {
        if active { activeTools.insert(tool.rawValue) }
        else { activeTools.remove(tool.rawValue) }
    }
}
