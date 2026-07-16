import Foundation

private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

struct DefaultBranchConfig: Codable, Equatable {
    var isEnabled: Bool = true
    var branchName: String = "main"
}

struct NotificationConfig: Codable {
    var sidebarSide: SidebarSide
    var isPriorityEnabled: Bool
    var isMacOSBannerEnabled: Bool
    /// When true, install a Cursor `stop` hook to fire attention notifications when the agent completes a turn.
    var isCursorHookAttentionEnabled: Bool
    var isPRMergedNotificationsEnabled: Bool
    var alwaysShowNotificationsSidebar: Bool
    /// When true, fire a notification when Claude finishes a turn.
    var isClaudeStopNotificationEnabled: Bool
    /// When true, fire a notification when OpenCode finishes a turn.
    var isOpencodeStopNotificationEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case sidebarSide
        case isPriorityEnabled
        case isMacOSBannerEnabled
        case isCursorHookAttentionEnabled
        case isPRMergedNotificationsEnabled
        case alwaysShowNotificationsSidebar
        case isClaudeStopNotificationEnabled
        case isOpencodeStopNotificationEnabled
    }

    init(
        sidebarSide: SidebarSide,
        isPriorityEnabled: Bool,
        isMacOSBannerEnabled: Bool,
        isCursorHookAttentionEnabled: Bool,
        isPRMergedNotificationsEnabled: Bool,
        alwaysShowNotificationsSidebar: Bool,
        isClaudeStopNotificationEnabled: Bool,
        isOpencodeStopNotificationEnabled: Bool
    ) {
        self.sidebarSide = sidebarSide
        self.isPriorityEnabled = isPriorityEnabled
        self.isMacOSBannerEnabled = isMacOSBannerEnabled
        self.isCursorHookAttentionEnabled = isCursorHookAttentionEnabled
        self.isPRMergedNotificationsEnabled = isPRMergedNotificationsEnabled
        self.alwaysShowNotificationsSidebar = alwaysShowNotificationsSidebar
        self.isClaudeStopNotificationEnabled = isClaudeStopNotificationEnabled
        self.isOpencodeStopNotificationEnabled = isOpencodeStopNotificationEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sidebarSide = try container.decodeIfPresent(SidebarSide.self, forKey: .sidebarSide) ?? .left
        isPriorityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPriorityEnabled) ?? true
        isMacOSBannerEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMacOSBannerEnabled) ?? true
        isCursorHookAttentionEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isCursorHookAttentionEnabled) ?? true
        isPRMergedNotificationsEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isPRMergedNotificationsEnabled) ?? true
        alwaysShowNotificationsSidebar =
            try container.decodeIfPresent(Bool.self, forKey: .alwaysShowNotificationsSidebar) ?? true
        isClaudeStopNotificationEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isClaudeStopNotificationEnabled) ?? true
        isOpencodeStopNotificationEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isOpencodeStopNotificationEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sidebarSide, forKey: .sidebarSide)
        try container.encode(isPriorityEnabled, forKey: .isPriorityEnabled)
        try container.encode(isMacOSBannerEnabled, forKey: .isMacOSBannerEnabled)
        try container.encode(isCursorHookAttentionEnabled, forKey: .isCursorHookAttentionEnabled)
        try container.encode(isPRMergedNotificationsEnabled, forKey: .isPRMergedNotificationsEnabled)
        try container.encode(alwaysShowNotificationsSidebar, forKey: .alwaysShowNotificationsSidebar)
        try container.encode(isClaudeStopNotificationEnabled, forKey: .isClaudeStopNotificationEnabled)
        try container.encode(isOpencodeStopNotificationEnabled, forKey: .isOpencodeStopNotificationEnabled)
    }
}

struct RestartConfig: Codable {
    var continueOnRestart: Bool = true
}

@MainActor
struct SettingsPersistence {
    nonisolated private static var appSupportDir: URL {
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
    private static var prPollingSettingsURL: URL { appSupportDir.appending(path: "pr-polling-settings.json") }
    private static var worktreeBaseRefURL: URL { appSupportDir.appending(path: "worktree-base-ref.json") }
    private static var exitBehaviorURL: URL { appSupportDir.appending(path: "exit-behavior.json") }
    private static var envVarSettingsURL: URL { appSupportDir.appending(path: "env-var-settings.json") }
    private static var opencodeEnvVarSettingsURL: URL {
        appSupportDir.appending(path: "opencode-env-var-settings.json")
    }
    private static var profilesURL: URL { appSupportDir.appending(path: "profiles.json") }
    private static var sessionNameSettingsURL: URL { appSupportDir.appending(path: "session-name-settings.json") }
    private static var shellSettingsURL: URL { appSupportDir.appending(path: "shell-settings.json") }
    private static var onboardingSettingsURL: URL { appSupportDir.appending(path: "onboarding-settings.json") }
    private static var activityIndicatorSettingsURL: URL {
        appSupportDir.appending(path: "activity-indicator-settings.json")
    }
    private static var focusModeSettingsURL: URL { appSupportDir.appending(path: "focus-mode-settings.json") }

    static func save<Value: Encodable>(_ value: Value, to filename: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: appSupportDir.appending(path: filename))
    }

    nonisolated static func load<Value: Decodable>(_ type: Value.Type, from filename: String) -> Value? {
        guard let data = try? Data(contentsOf: appSupportDir.appending(path: filename)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func loadFailableArray<Value: Decodable>(_ type: Value.Type, from filename: String) -> [Value] {
        guard let data = try? Data(contentsOf: appSupportDir.appending(path: filename)) else { return [] }
        return
            (try? JSONDecoder().decode([FailableDecodable<Value>].self, from: data))?
            .compactMap(\.value) ?? []
    }

    static func loadCLIOptions(from filename: String, harness: Harness) -> [CLIOptionConfig] {
        guard let data = try? Data(contentsOf: appSupportDir.appending(path: filename)) else { return [] }
        let decoder = JSONDecoder()
        decoder.userInfo[CLIOptionConfig.harnessUserInfoKey] = harness
        return
            (try? decoder.decode([FailableDecodable<CLIOptionConfig>].self, from: data))?
            .compactMap(\.value) ?? []
    }

    static func mergeCLIOptions(_ saved: [CLIOptionConfig], into defaults: [CLIOptionConfig]) -> [CLIOptionConfig] {
        var updated = defaults
        var userAdded: [CLIOptionConfig] = []
        for savedOption in saved {
            if savedOption.isUserAdded {
                userAdded.append(savedOption)
            } else if let index = updated.firstIndex(where: { $0.id == savedOption.id }) {
                updated[index].isAvailable = savedOption.isAvailable
                updated[index].isDefaultEnabled = savedOption.isDefaultEnabled
            }
        }
        return updated + userAdded
    }

    static func mergeEnvVarOptions(_ saved: [EnvVarConfig], into defaults: [EnvVarConfig]) -> [EnvVarConfig] {
        var updated = defaults
        var userAdded: [EnvVarConfig] = []
        for saved in saved {
            if saved.isUserAdded {
                userAdded.append(saved)
            } else if let index = updated.firstIndex(where: { $0.id == saved.id }) {
                updated[index].isAvailable = saved.isAvailable
                updated[index].isDefaultEnabled = saved.isDefaultEnabled
                updated[index].defaultValue = saved.defaultValue
            }
        }
        return updated + userAdded
    }

    static func save(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.cliOptions) else { return }
        try? data.write(to: settingsURL)
    }

    static func saveCodexOptions(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.codexCliOptions) else { return }
        try? data.write(to: codexSettingsURL)
    }

    static func saveCursorOptions(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.cursorCliOptions) else { return }
        try? data.write(to: cursorSettingsURL)
    }

    static func saveOpenCodeOptions(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.opencodeCliOptions) else { return }
        try? data.write(to: opencodeSettingsURL)
    }

    static func saveOpenCodeEnvVars(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.opencodeEnvVarOptions) else { return }
        try? data.write(to: opencodeEnvVarSettingsURL)
    }

    static func saveActiveTools(appSettings: AppSettings) {
        let sorted = appSettings.activeTools.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        try? data.write(to: activeToolsURL)
    }

    static func saveStatusLine(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.statusLineConfig) else { return }
        try? data.write(to: statusLineSettingsURL)
    }

    static func saveDefaultBranch(appSettings: AppSettings) {
        let config = DefaultBranchConfig(
            isEnabled: appSettings.isDefaultBranchEnabled, branchName: appSettings.defaultBranch)
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: defaultBranchURL)
    }

    static func saveNotificationSettings(appSettings: AppSettings) {
        let config = NotificationConfig(
            sidebarSide: appSettings.notificationSidebarSide,
            isPriorityEnabled: appSettings.isPriorityNotificationsEnabled,
            isMacOSBannerEnabled: appSettings.isMacOSBannerNotificationsEnabled,
            isCursorHookAttentionEnabled: appSettings.isCursorNotificationHookAttentionEnabled,
            isPRMergedNotificationsEnabled: appSettings.isPRMergedNotificationsEnabled,
            alwaysShowNotificationsSidebar: appSettings.alwaysShowNotificationsSidebar,
            isClaudeStopNotificationEnabled: appSettings.isClaudeStopNotificationEnabled,
            isOpencodeStopNotificationEnabled: appSettings.isOpencodeStopNotificationEnabled
        )
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: notificationSettingsURL)
    }

    static func isClaudeStopNotificationEnabled() -> Bool {
        guard
            let data = try? Data(contentsOf: notificationSettingsURL),
            let config = try? JSONDecoder().decode(NotificationConfig.self, from: data)
        else { return true }
        return config.isClaudeStopNotificationEnabled
    }

    static func isOpencodeStopNotificationEnabled() -> Bool {
        guard
            let data = try? Data(contentsOf: notificationSettingsURL),
            let config = try? JSONDecoder().decode(NotificationConfig.self, from: data)
        else { return true }
        return config.isOpencodeStopNotificationEnabled
    }

    static func isPRMergedNotificationsEnabled() -> Bool {
        guard
            let data = try? Data(contentsOf: notificationSettingsURL),
            let config = try? JSONDecoder().decode(NotificationConfig.self, from: data)
        else { return true }
        return config.isPRMergedNotificationsEnabled
    }

    struct DebugSettings: Codable {
        var schemaVersion: Int
        var enabled: Bool = false
    }

    static func isPRTrackingEnabled() -> Bool {
        guard
            let data = try? Data(contentsOf: prTrackingSettingsURL),
            let enabled = try? JSONDecoder().decode(Bool.self, from: data)
        else { return true }
        return enabled
    }

    struct TerminalSettings: Codable {
        var scrollbackLines: Int = 500
    }

    struct PRPollingSettings: Codable {
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

    static func prPollingSettings() -> PRPollingSettings {
        guard
            let data = try? Data(contentsOf: prPollingSettingsURL),
            let settings = try? JSONDecoder().decode(PRPollingSettings.self, from: data)
        else { return PRPollingSettings() }
        return PRPollingSettings(
            intervalSeconds: max(15, settings.intervalSeconds),
            timeoutSeconds: max(5, settings.timeoutSeconds),
            backgroundRefreshEnabled: settings.backgroundRefreshEnabled,
            backgroundIntervalSeconds: max(15, settings.backgroundIntervalSeconds)
        )
    }

    static func saveEnvVarOptions(appSettings: AppSettings) {
        guard let data = try? JSONEncoder().encode(appSettings.envVarOptions) else { return }
        try? data.write(to: envVarSettingsURL)
    }

    struct ProfilesContainer: Codable {
        var profiles: [Profile]
    }

    static func saveProfiles(appSettings: AppSettings) {
        let container = ProfilesContainer(profiles: appSettings.profiles)
        guard let data = try? JSONEncoder().encode(container) else { return }
        try? data.write(to: profilesURL)
    }

    struct ShellSettings: Codable {
        var preferredShell: String = ""
    }

    static func saveShellSettings(appSettings: AppSettings) {
        let payload = ShellSettings(preferredShell: appSettings.preferredShell)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: shellSettingsURL)
    }

    struct OnboardingSettings: Codable {
        var completed: Bool = false
    }

    struct ActivityIndicatorConfig: Codable {
        var enabled: Bool = true

        enum CodingKeys: String, CodingKey {
            case enabled
        }

        init(enabled: Bool) {
            self.enabled = enabled
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(enabled, forKey: .enabled)
        }
    }

    struct FocusModeConfig: Codable {
        var tabSwitchBehavior: FocusModeTabSwitchBehavior = .rememberFocus
        var hideNotificationSidebar: Bool = true
    }

    static func saveFocusModeSettings(appSettings: AppSettings) {
        let payload = FocusModeConfig(
            tabSwitchBehavior: appSettings.focusModeTabSwitchBehavior,
            hideNotificationSidebar: appSettings.hideNotificationSidebarWhileFocused
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: focusModeSettingsURL)
    }
}
