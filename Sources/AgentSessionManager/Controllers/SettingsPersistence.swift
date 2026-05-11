import Foundation

private struct DefaultBranchConfig: Codable, Equatable {
    var isEnabled: Bool = true
    var branchName: String = "main"
}

private struct NotificationConfig: Codable {
    var sidebarSide: SidebarSide
    var isPriorityEnabled: Bool
    var isMacOSBannerEnabled: Bool
    /// When true, merge Claude Code `Notification` hook into per-pane `--settings` so permission-style notifies reach the app without a terminal bell.
    var isClaudeHookAttentionEnabled: Bool
    var isPRMergedNotificationsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case sidebarSide
        case isPriorityEnabled
        case isMacOSBannerEnabled
        case isClaudeHookAttentionEnabled
        case isPRMergedNotificationsEnabled
    }

    init(
        sidebarSide: SidebarSide,
        isPriorityEnabled: Bool,
        isMacOSBannerEnabled: Bool,
        isClaudeHookAttentionEnabled: Bool,
        isPRMergedNotificationsEnabled: Bool
    ) {
        self.sidebarSide = sidebarSide
        self.isPriorityEnabled = isPriorityEnabled
        self.isMacOSBannerEnabled = isMacOSBannerEnabled
        self.isClaudeHookAttentionEnabled = isClaudeHookAttentionEnabled
        self.isPRMergedNotificationsEnabled = isPRMergedNotificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sidebarSide = try container.decodeIfPresent(SidebarSide.self, forKey: .sidebarSide) ?? .right
        isPriorityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPriorityEnabled) ?? true
        isMacOSBannerEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMacOSBannerEnabled) ?? true
        isClaudeHookAttentionEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isClaudeHookAttentionEnabled) ?? true
        isPRMergedNotificationsEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isPRMergedNotificationsEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sidebarSide, forKey: .sidebarSide)
        try container.encode(isPriorityEnabled, forKey: .isPriorityEnabled)
        try container.encode(isMacOSBannerEnabled, forKey: .isMacOSBannerEnabled)
        try container.encode(isClaudeHookAttentionEnabled, forKey: .isClaudeHookAttentionEnabled)
        try container.encode(isPRMergedNotificationsEnabled, forKey: .isPRMergedNotificationsEnabled)
    }
}

private struct RestartConfig: Codable {
    var continueOnRestart: Bool = true
}

@MainActor
struct SettingsPersistence {
    private static var appSupportDir: URL {
        let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = config.appending(path: PersistenceHelpers.appSupportSubdirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var settingsURL: URL { appSupportDir.appending(path: "settings.json") }
    private static var codexSettingsURL: URL { appSupportDir.appending(path: "codex-settings.json") }
    private static var cursorSettingsURL: URL { appSupportDir.appending(path: "cursor-settings.json") }
    private static var opencodeSettingsURL: URL { appSupportDir.appending(path: "opencode-settings.json") }
    private static var statusLineSettingsURL: URL { appSupportDir.appending(path: "statusline-settings.json") }
    private static var activeToolsURL: URL { appSupportDir.appending(path: "active-tools-settings.json") }
    private static var defaultBranchURL: URL { appSupportDir.appending(path: "default-branch.json") }
    private static var notificationSettingsURL: URL { appSupportDir.appending(path: "notification-settings.json") }
    private static var restartSettingsURL: URL { appSupportDir.appending(path: "restart-settings.json") }
    private static var worktreeCleanupURL: URL { appSupportDir.appending(path: "worktree-cleanup.json") }
    private static var existingWorktreeManagementURL: URL {
        appSupportDir.appending(path: "existing-worktree-management.json")
    }
    private static var debugSettingsURL: URL { appSupportDir.appending(path: "debug-settings.json") }
    private static var prTrackingSettingsURL: URL { appSupportDir.appending(path: "pr-tracking-settings.json") }
    private static var terminalSettingsURL: URL { appSupportDir.appending(path: "terminal-settings.json") }

    static func save(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.cliOptions) else { return }
        try? data.write(to: settingsURL)
    }

    static func restore(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: settingsURL),
            let saved = try? JSONDecoder().decode([CLIOptionConfig].self, from: data)
        else { return }

        var updated = CLIOptionConfig.all
        var userAdded: [CLIOptionConfig] = []
        for savedOption in saved {
            if savedOption.isUserAdded {
                userAdded.append(savedOption)
            } else if let index = updated.firstIndex(where: { $0.id == savedOption.id }) {
                updated[index].isAvailable = savedOption.isAvailable
                updated[index].isDefaultEnabled = savedOption.isDefaultEnabled
            }
        }
        appSettings.cliOptions = updated + userAdded
    }

    static func saveCodexOptions(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.codexCliOptions) else { return }
        try? data.write(to: codexSettingsURL)
    }

    static func restoreCodexOptions(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: codexSettingsURL),
            let saved = try? JSONDecoder().decode([CLIOptionConfig].self, from: data)
        else { return }

        var updated = CLIOptionConfig.codexAll
        var userAdded: [CLIOptionConfig] = []
        for savedOption in saved {
            if savedOption.isUserAdded {
                userAdded.append(savedOption)
            } else if let index = updated.firstIndex(where: { $0.id == savedOption.id }) {
                updated[index].isAvailable = savedOption.isAvailable
                updated[index].isDefaultEnabled = savedOption.isDefaultEnabled
            }
        }
        appSettings.codexCliOptions = updated + userAdded
    }

    static func saveCursorOptions(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.cursorCliOptions) else { return }
        try? data.write(to: cursorSettingsURL)
    }

    static func restoreCursorOptions(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: cursorSettingsURL),
            let saved = try? JSONDecoder().decode([CLIOptionConfig].self, from: data)
        else { return }

        var updated = CLIOptionConfig.cursorAll
        var userAdded: [CLIOptionConfig] = []
        for savedOption in saved {
            if savedOption.isUserAdded {
                userAdded.append(savedOption)
            } else if let index = updated.firstIndex(where: { $0.id == savedOption.id }) {
                updated[index].isAvailable = savedOption.isAvailable
                updated[index].isDefaultEnabled = savedOption.isDefaultEnabled
            }
        }
        appSettings.cursorCliOptions = updated + userAdded
    }

    static func saveOpenCodeOptions(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.opencodeCliOptions) else { return }
        try? data.write(to: opencodeSettingsURL)
    }

    static func restoreOpenCodeOptions(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: opencodeSettingsURL),
            let saved = try? JSONDecoder().decode([CLIOptionConfig].self, from: data)
        else { return }

        var updated = CLIOptionConfig.opencodeAll
        var userAdded: [CLIOptionConfig] = []
        for savedOption in saved {
            if savedOption.isUserAdded {
                userAdded.append(savedOption)
            } else if let index = updated.firstIndex(where: { $0.id == savedOption.id }) {
                updated[index].isAvailable = savedOption.isAvailable
                updated[index].isDefaultEnabled = savedOption.isDefaultEnabled
            }
        }
        appSettings.opencodeCliOptions = updated + userAdded
    }

    static func saveActiveTools(appSettings: AppSettings) {
        let sorted = appSettings.activeTools.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        try? data.write(to: activeToolsURL)
    }

    static func restoreActiveTools(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: activeToolsURL),
            let saved = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        let knownRaws = Set(CLIType.allCases.map(\.rawValue))
        appSettings.activeTools = Set(saved).intersection(knownRaws)
    }

    static func saveStatusLine(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.statusLineConfig) else { return }
        try? data.write(to: statusLineSettingsURL)
    }

    static func restoreStatusLine(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: statusLineSettingsURL),
            let saved = try? JSONDecoder().decode(StatusLineConfig.self, from: data)
        else { return }
        appSettings.statusLineConfig = saved
    }

    static func saveDefaultBranch(appSettings: AppSettings) {
        let config = DefaultBranchConfig(
            isEnabled: appSettings.isDefaultBranchEnabled, branchName: appSettings.defaultBranch)
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: defaultBranchURL)
    }

    static func restoreDefaultBranch(into appSettings: AppSettings) {
        guard let data = try? Data(contentsOf: defaultBranchURL) else { return }
        if let config = try? JSONDecoder().decode(DefaultBranchConfig.self, from: data) {
            appSettings.isDefaultBranchEnabled = config.isEnabled
            appSettings.defaultBranch = config.branchName
        } else if let saved = try? JSONDecoder().decode(String.self, from: data), !saved.isEmpty {
            appSettings.defaultBranch = saved
            appSettings.isDefaultBranchEnabled = true
        }
    }

    static func saveNotificationSettings(appSettings: AppSettings) {
        let config = NotificationConfig(
            sidebarSide: appSettings.notificationSidebarSide,
            isPriorityEnabled: appSettings.isPriorityNotificationsEnabled,
            isMacOSBannerEnabled: appSettings.isMacOSBannerNotificationsEnabled,
            isClaudeHookAttentionEnabled: appSettings.isClaudeNotificationHookAttentionEnabled,
            isPRMergedNotificationsEnabled: appSettings.isPRMergedNotificationsEnabled
        )
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: notificationSettingsURL)
    }

    static func restoreNotificationSettings(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: notificationSettingsURL),
            let config = try? JSONDecoder().decode(NotificationConfig.self, from: data)
        else { return }
        appSettings.notificationSidebarSide = config.sidebarSide
        appSettings.isPriorityNotificationsEnabled = config.isPriorityEnabled
        appSettings.isMacOSBannerNotificationsEnabled = config.isMacOSBannerEnabled
        appSettings.isClaudeNotificationHookAttentionEnabled = config.isClaudeHookAttentionEnabled
        appSettings.isPRMergedNotificationsEnabled = config.isPRMergedNotificationsEnabled
    }

    static func isClaudeHookAttentionEnabled() -> Bool {
        guard
            let data = try? Data(contentsOf: notificationSettingsURL),
            let config = try? JSONDecoder().decode(NotificationConfig.self, from: data)
        else { return true }
        return config.isClaudeHookAttentionEnabled
    }

    static func isPRMergedNotificationsEnabled() -> Bool {
        guard
            let data = try? Data(contentsOf: notificationSettingsURL),
            let config = try? JSONDecoder().decode(NotificationConfig.self, from: data)
        else { return true }
        return config.isPRMergedNotificationsEnabled
    }

    static func saveRestartSettings(appSettings: AppSettings) {
        let config = RestartConfig(continueOnRestart: appSettings.continueOnRestart)
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: restartSettingsURL)
    }

    static func restoreRestartSettings(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: restartSettingsURL),
            let config = try? JSONDecoder().decode(RestartConfig.self, from: data)
        else { return }
        appSettings.continueOnRestart = config.continueOnRestart
    }

    static func saveWorktreeCleanup(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.worktreeCleanupBehavior) else { return }
        try? data.write(to: worktreeCleanupURL)
    }

    static func restoreWorktreeCleanup(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: worktreeCleanupURL),
            let behavior = try? JSONDecoder().decode(WorktreeCleanupBehavior.self, from: data)
        else { return }
        appSettings.worktreeCleanupBehavior = behavior
    }

    static func saveExistingWorktreeManagement(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.existingWorktreeManagement) else { return }
        try? data.write(to: existingWorktreeManagementURL)
    }

    static func restoreExistingWorktreeManagement(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: existingWorktreeManagementURL),
            let behavior = try? JSONDecoder().decode(ExistingWorktreeManagement.self, from: data)
        else { return }
        appSettings.existingWorktreeManagement = behavior
    }

    private struct DebugSettings: Codable, Equatable {
        var enabled: Bool = false
        var logFilePath: String = ""
        var maxFileBytes: Int = 15 * 1024 * 1024
        var includeTerminalContents: Bool = false
    }

    static func saveDebugSettings(appSettings: AppSettings) {
        let payload = DebugSettings(
            enabled: appSettings.debugLoggingEnabled,
            logFilePath: appSettings.debugLogFilePath,
            maxFileBytes: max(1_048_576, appSettings.debugLogMaxFileBytes),
            includeTerminalContents: appSettings.debugLogIncludeTerminalContents
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: debugSettingsURL)
    }

    static func restoreDebugSettings(into appSettings: AppSettings) {
        guard let data = try? Data(contentsOf: debugSettingsURL) else { return }
        if let settings = try? JSONDecoder().decode(DebugSettings.self, from: data) {
            appSettings.debugLoggingEnabled = settings.enabled
            appSettings.debugLogFilePath = settings.logFilePath
            appSettings.debugLogMaxFileBytes = max(1_048_576, settings.maxFileBytes)
            appSettings.debugLogIncludeTerminalContents = settings.includeTerminalContents
            return
        }
        if let legacy = try? JSONDecoder().decode(Bool.self, from: data) {
            appSettings.debugLoggingEnabled = legacy
        }
    }

    static func savePRTracking(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.githubPRTrackingEnabled) else { return }
        try? data.write(to: prTrackingSettingsURL)
    }

    static func restorePRTracking(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: prTrackingSettingsURL),
            let enabled = try? JSONDecoder().decode(Bool.self, from: data)
        else { return }
        appSettings.githubPRTrackingEnabled = enabled
    }

    static func isPRTrackingEnabled() -> Bool {
        guard
            let data = try? Data(contentsOf: prTrackingSettingsURL),
            let enabled = try? JSONDecoder().decode(Bool.self, from: data)
        else { return true }
        return enabled
    }

    private struct TerminalSettings: Codable {
        var scrollbackLines: Int = 500
    }

    static func saveTerminalSettings(appSettings: AppSettings) {
        let payload = TerminalSettings(scrollbackLines: appSettings.scrollbackLines)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: terminalSettingsURL)
    }

    static func restoreTerminalSettings(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: terminalSettingsURL),
            let settings = try? JSONDecoder().decode(TerminalSettings.self, from: data)
        else { return }
        appSettings.scrollbackLines = settings.scrollbackLines
    }
}
