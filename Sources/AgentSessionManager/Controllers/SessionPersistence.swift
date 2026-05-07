import Foundation

struct PersistedSession: Codable {
    var tabs: [PersistedTab]
    var activeTabIndex: Int?
}

struct PersistedTab: Codable {
    var id: UUID
    var name: String
    var directory: String
    var panes: [PersistedPane]
}

struct PersistedPane: Codable {
    var id: UUID
    var name: String
    var cliType: CLIType
    var isPriority: Bool
    var worktreeDirectory: String?
    var worktreeIsManaged: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, cliType, isPriority, worktreeDirectory, worktreeIsManaged
        case claudeProcessDirectory
    }

    init(id: UUID, name: String, cliType: CLIType, isPriority: Bool = false, worktreeDirectory: String? = nil, worktreeIsManaged: Bool = false) {
        self.id = id
        self.name = name
        self.cliType = cliType
        self.isPriority = isPriority
        self.worktreeDirectory = worktreeDirectory
        self.worktreeIsManaged = worktreeIsManaged
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cliType = (try? container.decodeIfPresent(CLIType.self, forKey: .cliType)) ?? .claude
        isPriority = (try? container.decodeIfPresent(Bool.self, forKey: .isPriority)) ?? false
        worktreeDirectory = try container.decodeIfPresent(String.self, forKey: .worktreeDirectory)
            ?? container.decodeIfPresent(String.self, forKey: .claudeProcessDirectory)
        worktreeIsManaged = (try? container.decodeIfPresent(Bool.self, forKey: .worktreeIsManaged)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(cliType, forKey: .cliType)
        try container.encode(isPriority, forKey: .isPriority)
        try container.encode(worktreeDirectory, forKey: .worktreeDirectory)
        try container.encode(worktreeIsManaged, forKey: .worktreeIsManaged)
    }
}

@MainActor
struct SessionPersistence {
    private static var sessionURL: URL {
        let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = config.appending(path: "agent-session-manager")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "sessions.json")
    }

    static func save(appState: AppState) {
        let tabs = appState.tabs.map { tab in
            PersistedTab(
                id: tab.id,
                name: tab.name,
                directory: tab.directory.path,
                panes: tab.panes.map {
                    PersistedPane(
                        id: $0.id,
                        name: $0.name,
                        cliType: $0.cliType,
                        isPriority: $0.isPriority,
                        worktreeDirectory: $0.worktreeDirectory?.path,
                        worktreeIsManaged: $0.worktreeIsManaged
                    )
                }
            )
        }
        let activeTabIndex = appState.tabs.firstIndex { $0.id == appState.activeTabID }
        let session = PersistedSession(tabs: tabs, activeTabIndex: activeTabIndex)
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: sessionURL)
    }

    static func restore(into appState: AppState, appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: sessionURL),
            let session = try? JSONDecoder().decode(PersistedSession.self, from: data)
        else { return }

        for persistedTab in session.tabs {
            guard let dir = URL(string: "file://\(persistedTab.directory)") else { continue }
            let tab = Tab(name: persistedTab.name, directory: dir)
            for persistedPane in persistedTab.panes {
                let worktreeDir: URL?
                if let pathStr = persistedPane.worktreeDirectory, !pathStr.isEmpty {
                    let url = URL(fileURLWithPath: pathStr).standardizedFileURL
                    guard FileManager.default.fileExists(atPath: url.path) else { continue }
                    worktreeDir = url
                } else if persistedPane.cliType == .claude {
                    let managed = Tab.worktreeDirectoryURL(repoRoot: dir, name: persistedPane.name)
                    let legacy = dir.appending(path: ".tree/\(persistedPane.name)", directoryHint: .notDirectory)
                    if FileManager.default.fileExists(atPath: managed.path) {
                        worktreeDir = managed
                    } else if FileManager.default.fileExists(atPath: legacy.path) {
                        worktreeDir = legacy
                    } else {
                        continue
                    }
                } else {
                    continue
                }
                let extraArgs = persistedPane.cliType == .claude && appSettings.continueOnRestart ? ["--continue"] : []
                let pane = tab.addPane(
                    name: persistedPane.name,
                    extraArgs: extraArgs,
                    cliType: persistedPane.cliType,
                    worktreeDirectory: worktreeDir,
                    worktreeIsManaged: persistedPane.worktreeIsManaged
                )
                pane.wireTerminalBellForNotifications(
                    appState: appState,
                    tab: tab,
                    isPriority: persistedPane.isPriority
                )
            }
            appState.tabs.append(tab)
        }
        if let index = session.activeTabIndex, index < appState.tabs.count {
            appState.activeTabID = appState.tabs[index].id
        } else {
            appState.activeTabID = appState.tabs.first?.id
        }
    }
}
