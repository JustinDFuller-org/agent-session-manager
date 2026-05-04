import Foundation

@MainActor
struct SettingsPersistence {
    private static var appSupportDir: URL {
        let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = config.appending(path: "agent-session-manager")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var settingsURL: URL { appSupportDir.appending(path: "settings.json") }
    private static var codexSettingsURL: URL { appSupportDir.appending(path: "codex-settings.json") }
    private static var statusLineSettingsURL: URL { appSupportDir.appending(path: "statusline-settings.json") }
    private static var activeToolsURL: URL { appSupportDir.appending(path: "active-tools-settings.json") }

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
}
