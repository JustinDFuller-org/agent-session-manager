import Foundation
import Observation

enum WorktreeCleanupBehavior: String, Codable, CaseIterable {
    case ask
    case keep
    case delete

    var displayName: String {
        switch self {
        case .ask: return "Ask"
        case .keep: return "Always Keep"
        case .delete: return "Always Delete"
        }
    }

    var description: String {
        switch self {
        case .ask: return "Ask whether to clean up the worktree each time you close a pane."
        case .keep: return "Never delete worktrees when closing a pane."
        case .delete: return "Automatically delete worktrees when closing a pane without asking."
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    var cliOptions: [CLIOptionConfig] = CLIOptionConfig.all
    var codexCliOptions: [CLIOptionConfig] = CLIOptionConfig.codexAll
    var cursorCliOptions: [CLIOptionConfig] = CLIOptionConfig.cursorAll
    var statusLineConfig: StatusLineConfig = StatusLineConfig()
    var activeTools: Set<String> = [CLIType.claude.rawValue]
    var defaultBranch: String = "main"
    var isDefaultBranchEnabled: Bool = true
    var notificationSidebarSide: SidebarSide = .right
    var isPriorityNotificationsEnabled: Bool = true
    var continueOnRestart: Bool = true
    var worktreeCleanupBehavior: WorktreeCleanupBehavior = .ask

    func isActive(_ tool: CLIType) -> Bool {
        activeTools.contains(tool.rawValue)
    }

    func setActive(_ tool: CLIType, _ active: Bool) {
        if active { activeTools.insert(tool.rawValue) }
        else { activeTools.remove(tool.rawValue) }
    }
}
