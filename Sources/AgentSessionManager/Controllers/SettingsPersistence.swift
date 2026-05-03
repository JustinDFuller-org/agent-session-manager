import Foundation

@MainActor
struct SettingsPersistence {
    private static var settingsURL: URL {
        let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = config.appending(path: "agent-session-manager")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "settings.json")
    }

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
}
