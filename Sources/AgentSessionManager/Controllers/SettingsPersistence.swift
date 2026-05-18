import Foundation

private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

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
    /// When true, install a Cursor `stop` hook to fire attention notifications when the agent completes a turn.
    var isCursorHookAttentionEnabled: Bool
    var isPRMergedNotificationsEnabled: Bool
    var alwaysShowNotificationsSidebar: Bool
    var isStickyNotificationsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case sidebarSide
        case isPriorityEnabled
        case isMacOSBannerEnabled
        case isClaudeHookAttentionEnabled
        case isCursorHookAttentionEnabled
        case isPRMergedNotificationsEnabled
        case alwaysShowNotificationsSidebar
        case isStickyNotificationsEnabled
    }

    init(
        sidebarSide: SidebarSide,
        isPriorityEnabled: Bool,
        isMacOSBannerEnabled: Bool,
        isClaudeHookAttentionEnabled: Bool,
        isCursorHookAttentionEnabled: Bool,
        isPRMergedNotificationsEnabled: Bool,
        alwaysShowNotificationsSidebar: Bool,
        isStickyNotificationsEnabled: Bool = false
    ) {
        self.sidebarSide = sidebarSide
        self.isPriorityEnabled = isPriorityEnabled
        self.isMacOSBannerEnabled = isMacOSBannerEnabled
        self.isClaudeHookAttentionEnabled = isClaudeHookAttentionEnabled
        self.isCursorHookAttentionEnabled = isCursorHookAttentionEnabled
        self.isPRMergedNotificationsEnabled = isPRMergedNotificationsEnabled
        self.alwaysShowNotificationsSidebar = alwaysShowNotificationsSidebar
        self.isStickyNotificationsEnabled = isStickyNotificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sidebarSide = try container.decodeIfPresent(SidebarSide.self, forKey: .sidebarSide) ?? .right
        isPriorityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPriorityEnabled) ?? true
        isMacOSBannerEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMacOSBannerEnabled) ?? true
        isClaudeHookAttentionEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isClaudeHookAttentionEnabled) ?? true
        isCursorHookAttentionEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isCursorHookAttentionEnabled) ?? true
        isPRMergedNotificationsEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isPRMergedNotificationsEnabled) ?? true
        alwaysShowNotificationsSidebar =
            try container.decodeIfPresent(Bool.self, forKey: .alwaysShowNotificationsSidebar) ?? true
        isStickyNotificationsEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isStickyNotificationsEnabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sidebarSide, forKey: .sidebarSide)
        try container.encode(isPriorityEnabled, forKey: .isPriorityEnabled)
        try container.encode(isMacOSBannerEnabled, forKey: .isMacOSBannerEnabled)
        try container.encode(isClaudeHookAttentionEnabled, forKey: .isClaudeHookAttentionEnabled)
        try container.encode(isCursorHookAttentionEnabled, forKey: .isCursorHookAttentionEnabled)
        try container.encode(isPRMergedNotificationsEnabled, forKey: .isPRMergedNotificationsEnabled)
        try container.encode(alwaysShowNotificationsSidebar, forKey: .alwaysShowNotificationsSidebar)
        try container.encode(isStickyNotificationsEnabled, forKey: .isStickyNotificationsEnabled)
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
    private static var tracingSettingsURL: URL { appSupportDir.appending(path: "tracing-settings.json") }
    private static var prTrackingSettingsURL: URL { appSupportDir.appending(path: "pr-tracking-settings.json") }
    private static var terminalSettingsURL: URL { appSupportDir.appending(path: "terminal-settings.json") }
    private static var prPollingSettingsURL: URL { appSupportDir.appending(path: "pr-polling-settings.json") }
    private static var worktreeBaseRefURL: URL { appSupportDir.appending(path: "worktree-base-ref.json") }
    private static var exitBehaviorURL: URL { appSupportDir.appending(path: "exit-behavior.json") }
    private static var envVarSettingsURL: URL { appSupportDir.appending(path: "env-var-settings.json") }
    private static var profilesURL: URL { appSupportDir.appending(path: "profiles.json") }
    private static var sessionNameSettingsURL: URL { appSupportDir.appending(path: "session-name-settings.json") }

    static func save(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.cliOptions) else { return }
        try? data.write(to: settingsURL)
    }

    static func restore(into appSettings: AppSettings) {
        guard let data = try? Data(contentsOf: settingsURL) else { return }
        let failable = try? JSONDecoder().decode([FailableDecodable<CLIOptionConfig>].self, from: data)
        let saved = failable?.compactMap(\.value) ?? []

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
        guard let data = try? Data(contentsOf: codexSettingsURL) else { return }
        let failable = try? JSONDecoder().decode([FailableDecodable<CLIOptionConfig>].self, from: data)
        let saved = failable?.compactMap(\.value) ?? []

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
        guard let data = try? Data(contentsOf: cursorSettingsURL) else { return }
        let failable = try? JSONDecoder().decode([FailableDecodable<CLIOptionConfig>].self, from: data)
        let saved = failable?.compactMap(\.value) ?? []

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
        guard let data = try? Data(contentsOf: opencodeSettingsURL) else { return }
        let failable = try? JSONDecoder().decode([FailableDecodable<CLIOptionConfig>].self, from: data)
        let saved = failable?.compactMap(\.value) ?? []

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
            isCursorHookAttentionEnabled: appSettings.isCursorNotificationHookAttentionEnabled,
            isPRMergedNotificationsEnabled: appSettings.isPRMergedNotificationsEnabled,
            alwaysShowNotificationsSidebar: appSettings.alwaysShowNotificationsSidebar,
            isStickyNotificationsEnabled: appSettings.isStickyNotificationsEnabled
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
        appSettings.isCursorNotificationHookAttentionEnabled = config.isCursorHookAttentionEnabled
        appSettings.isPRMergedNotificationsEnabled = config.isPRMergedNotificationsEnabled
        appSettings.alwaysShowNotificationsSidebar = config.alwaysShowNotificationsSidebar
        appSettings.isStickyNotificationsEnabled = config.isStickyNotificationsEnabled
    }

    static func isClaudeHookAttentionEnabled() -> Bool {
        guard
            let data = try? Data(contentsOf: notificationSettingsURL),
            let config = try? JSONDecoder().decode(NotificationConfig.self, from: data)
        else { return true }
        return config.isClaudeHookAttentionEnabled
    }

    nonisolated static func isCursorHookAttentionEnabled() -> Bool {
        let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = config.appending(path: PersistenceHelpers.appSupportSubdirectory)
            .appending(path: "notification-settings.json")
        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(NotificationConfig.self, from: data)
        else { return true }
        return decoded.isCursorHookAttentionEnabled
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

    private struct TracingSettings: Codable {
        var enabled: Bool = false
        var outputTarget: TracingOutputTarget = .stdout
        var filePath: String = ""
        var maxFileBytes: Int = AppSettings.defaultTracingFileMaxBytes
    }

    static func saveTracingSettings(appSettings: AppSettings) {
        let payload = TracingSettings(
            enabled: appSettings.tracingEnabled,
            outputTarget: appSettings.tracingOutputTarget,
            filePath: appSettings.tracingFilePath,
            maxFileBytes: max(1_048_576, appSettings.tracingFileMaxBytes)
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: tracingSettingsURL)
    }

    static func restoreTracingSettings(into appSettings: AppSettings) {
        guard let data = try? Data(contentsOf: tracingSettingsURL) else { return }
        guard let settings = try? JSONDecoder().decode(TracingSettings.self, from: data) else { return }
        appSettings.tracingEnabled = settings.enabled
        appSettings.tracingOutputTarget = settings.outputTarget
        appSettings.tracingFilePath = settings.filePath
        appSettings.tracingFileMaxBytes = max(1_048_576, settings.maxFileBytes)
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

    static func saveWorktreeBaseRef(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.worktreeBaseRef) else { return }
        try? data.write(to: worktreeBaseRefURL)
    }

    static func restoreWorktreeBaseRef(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: worktreeBaseRefURL),
            let value = try? JSONDecoder().decode(WorktreeBaseRef.self, from: data)
        else { return }
        appSettings.worktreeBaseRef = value
    }

    static func saveExitBehavior(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.exitBehavior) else { return }
        try? data.write(to: exitBehaviorURL)
    }

    static func restoreExitBehavior(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: exitBehaviorURL),
            let value = try? JSONDecoder().decode(ExitBehavior.self, from: data)
        else { return }
        appSettings.exitBehavior = value
    }

    private struct PRPollingSettings: Codable {
        var intervalSeconds: Int = 30
        var timeoutSeconds: Int = 15
        var backgroundRefreshEnabled: Bool = true
        var backgroundIntervalSeconds: Int = 60
    }

    static func savePRPollingSettings(appSettings: AppSettings) {
        let payload = PRPollingSettings(
            intervalSeconds: appSettings.prPollingIntervalSeconds,
            timeoutSeconds: appSettings.prRequestTimeoutSeconds,
            backgroundRefreshEnabled: appSettings.prBackgroundRefreshEnabled,
            backgroundIntervalSeconds: appSettings.prBackgroundPollingIntervalSeconds
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: prPollingSettingsURL)
    }

    static func restorePRPollingSettings(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: prPollingSettingsURL),
            let settings = try? JSONDecoder().decode(PRPollingSettings.self, from: data)
        else { return }
        appSettings.prPollingIntervalSeconds = max(15, settings.intervalSeconds)
        appSettings.prRequestTimeoutSeconds = max(5, settings.timeoutSeconds)
        appSettings.prBackgroundRefreshEnabled = settings.backgroundRefreshEnabled
        appSettings.prBackgroundPollingIntervalSeconds = max(15, settings.backgroundIntervalSeconds)
    }

    static func prPollingSettings() -> (
        intervalSeconds: Int, timeoutSeconds: Int, backgroundRefreshEnabled: Bool,
        backgroundIntervalSeconds: Int
    ) {
        guard
            let data = try? Data(contentsOf: prPollingSettingsURL),
            let settings = try? JSONDecoder().decode(PRPollingSettings.self, from: data)
        else { return (30, 15, true, 60) }
        return (
            max(15, settings.intervalSeconds), max(5, settings.timeoutSeconds),
            settings.backgroundRefreshEnabled, max(15, settings.backgroundIntervalSeconds)
        )
    }

    static func saveEnvVarOptions(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.envVarOptions) else { return }
        try? data.write(to: envVarSettingsURL)
    }

    static func restoreEnvVarOptions(into appSettings: AppSettings) {
        guard let data = try? Data(contentsOf: envVarSettingsURL) else { return }
        let failable = try? JSONDecoder().decode([FailableDecodable<EnvVarConfig>].self, from: data)
        let saved = failable?.compactMap(\.value) ?? []
        if saved.isEmpty { return }

        var updated = EnvVarConfig.all
        var userAdded: [EnvVarConfig] = []
        for savedOption in saved {
            if savedOption.isUserAdded {
                userAdded.append(savedOption)
            } else if let index = updated.firstIndex(where: { $0.id == savedOption.id }) {
                updated[index].isAvailable = savedOption.isAvailable
                updated[index].isDefaultEnabled = savedOption.isDefaultEnabled
                updated[index].defaultValue = savedOption.defaultValue
            }
        }
        appSettings.envVarOptions = updated + userAdded
    }

    private struct ProfilesContainer: Codable {
        var profiles: [Profile]
    }

    static func saveProfiles(appSettings: AppSettings) {
        let container = ProfilesContainer(profiles: appSettings.profiles)
        guard let data = try? JSONEncoder().encode(container) else { return }
        try? data.write(to: profilesURL)
    }

    static func restoreProfiles(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: profilesURL),
            let container = try? JSONDecoder().decode(ProfilesContainer.self, from: data)
        else { return }
        appSettings.profiles = container.profiles
    }

    static func saveSessionNameSettings(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.autoSetSessionName) else { return }
        try? data.write(to: sessionNameSettingsURL)
    }

    static func restoreSessionNameSettings(into appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: sessionNameSettingsURL),
            let value = try? JSONDecoder().decode(Bool.self, from: data)
        else { return }
        appSettings.autoSetSessionName = value
    }
}
