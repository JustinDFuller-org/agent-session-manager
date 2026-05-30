import Foundation
import Observation

enum ExitBehavior: String, Codable, CaseIterable {
    case prompt
    case autoShell
    case close

    var displayName: String {
        switch self {
        case .prompt: return "Show Prompt"
        case .autoShell: return "Open Shell"
        case .close: return "Close Pane"
        }
    }

    var description: String {
        switch self {
        case .prompt: return "Show a prompt offering Restart, Open Shell, and Close when a process exits."
        case .autoShell: return "Automatically replace the pane with a live shell when a process exits."
        case .close: return "Automatically close the pane when a process exits."
        }
    }
}

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

enum WorktreeBaseRef: String, Codable, CaseIterable {
    case fresh
    case head

    var displayName: String {
        switch self {
        case .fresh: return "Fresh"
        case .head: return "HEAD"
        }
    }

    var description: String {
        switch self {
        case .fresh: return "Branch from origin/<default-branch> for a clean tree matching the remote."
        case .head: return "Branch from local HEAD, including unpushed commits and current branch state."
        }
    }
}

enum ExistingWorktreeManagement: String, Codable, CaseIterable {
    case ask
    case always
    case never

    var displayName: String {
        switch self {
        case .ask: return "Ask"
        case .always: return "Always"
        case .never: return "Never"
        }
    }

    var description: String {
        switch self {
        case .ask: return "Ask whether to take over management each time an existing worktree is reused."
        case .always: return "Automatically take over management of existing worktrees so they can be cleaned up later."
        case .never: return "Never manage existing worktrees — use them as-is without offering cleanup."
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    var cliOptions: [CLIOptionConfig] = CLIOptionConfig.all
    var codexCliOptions: [CLIOptionConfig] = CLIOptionConfig.codexAll
    var cursorCliOptions: [CLIOptionConfig] = CLIOptionConfig.cursorAll
    var envVarOptions: [EnvVarConfig] = EnvVarConfig.all
    var statusLineConfig = StatusLineConfig()
    var activeTools: Set<String> = [Harness.claude.rawValue]
    var defaultBranch: String = "main"
    var isDefaultBranchEnabled: Bool = true
    var notificationSidebarSide: SidebarSide = .right
    var alwaysShowNotificationsSidebar: Bool = true
    var isPriorityNotificationsEnabled: Bool = true
    var isMacOSBannerNotificationsEnabled: Bool = true
    /// Merges Claude Code `Notification` hook into per-pane `--settings` for attention when the terminal does not ring the bell (default on).
    var isClaudeNotificationHookAttentionEnabled: Bool = true
    /// Installs a Cursor `stop` hook to fire attention notifications when the agent completes a turn.
    var isCursorNotificationHookAttentionEnabled: Bool = true
    var continueOnRestart: Bool = true
    var worktreeCleanupBehavior: WorktreeCleanupBehavior = .ask
    var existingWorktreeManagement: ExistingWorktreeManagement = .ask
    var worktreeBaseRef: WorktreeBaseRef = .fresh
    var debugModeEnabled: Bool = false
    var githubPRTrackingEnabled: Bool = true
    var isPRMergedNotificationsEnabled: Bool = true
    var prPollingIntervalSeconds: Int = 30
    var prRequestTimeoutSeconds: Int = 15
    var prBackgroundRefreshEnabled: Bool = true
    var prBackgroundPollingIntervalSeconds: Int = 60
    var scrollbackLines: Int = 500
    var exitBehavior: ExitBehavior = .prompt
    var profiles: [Profile] = []
    var autoSetSessionName: Bool = true
    /// Persisted shell path; empty string means auto-detect from $SHELL.
    var preferredShell: String = ""
    var hasCompletedOnboarding: Bool = false
    var paneActivityIndicatorsEnabled: Bool = true

    nonisolated static let debugFileMaxBytes = 10 * 1024 * 1024

    /// Fixed traces directory URL used while Debug mode is enabled.
    var resolvedTracingDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return
            appSupport
            .appending(path: PersistenceHelpers.appSupportSubdirectory)
            .appending(path: "traces")
            .standardizedFileURL
    }

    /// Fixed invariant log directory URL used while Debug mode is enabled.
    var resolvedInvariantDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return
            appSupport
            .appending(path: PersistenceHelpers.appSupportSubdirectory)
            .appending(path: "invariants")
            .standardizedFileURL
    }

    func isActive(_ tool: Harness) -> Bool {
        activeTools.contains(tool.rawValue)
    }

    func setActive(_ tool: Harness, _ active: Bool) {
        if active { activeTools.insert(tool.rawValue) } else { activeTools.remove(tool.rawValue) }
    }

    /// User-facing harness types currently enabled in Tools, in canonical `Harness.allCases` order.
    var activeHarnesses: [Harness] {
        Harness.allCases.filter { isActive($0) }
    }
}
