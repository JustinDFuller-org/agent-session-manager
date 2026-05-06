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
    /// Absolute path when Claude runs in a reused checkout (not under `.agent-session-manager/worktrees/`).
    var claudeProcessDirectory: String?

    init(id: UUID, name: String, cliType: CLIType, isPriority: Bool = false, claudeProcessDirectory: String? = nil) {
        self.id = id
        self.name = name
        self.cliType = cliType
        self.isPriority = isPriority
        self.claudeProcessDirectory = claudeProcessDirectory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cliType = (try? container.decodeIfPresent(CLIType.self, forKey: .cliType)) ?? .claude
        isPriority = (try? container.decodeIfPresent(Bool.self, forKey: .isPriority)) ?? false
        claudeProcessDirectory = try container.decodeIfPresent(String.self, forKey: .claudeProcessDirectory)
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
                        claudeProcessDirectory: $0.claudeDirectoryOverride?.path
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
                if persistedPane.cliType == .claude {
                    if let pathStr = persistedPane.claudeProcessDirectory {
                        let override = URL(fileURLWithPath: pathStr).standardizedFileURL
                        guard FileManager.default.fileExists(atPath: override.path) else { continue }
                        tab.addPane(
                            name: persistedPane.name,
                            extraArgs: appSettings.continueOnRestart ? ["--continue"] : [],
                            cliType: persistedPane.cliType,
                            claudeDirectoryOverride: override
                        )
                        if let pane = tab.panes.last {
                            pane.isPriority = persistedPane.isPriority
                            pane.terminalController?.onBell = { [weak appState, weak tab, weak pane] in
                                Task { @MainActor in
                                    guard let appState, let tab, let pane else { return }
                                    appState.addNotification(
                                        paneID: pane.id,
                                        paneName: pane.name,
                                        tabID: tab.id,
                                        tabName: tab.name,
                                        isPriority: pane.isPriority
                                    )
                                }
                            }
                        }
                        continue
                    }
                    let managed = Tab.worktreeDirectoryURL(repoRoot: dir, name: persistedPane.name)
                    let legacy = dir.appending(path: ".tree/\(persistedPane.name)", directoryHint: .notDirectory)
                    let hasWorktree = FileManager.default.fileExists(atPath: managed.path)
                        || FileManager.default.fileExists(atPath: legacy.path)
                    guard hasWorktree else { continue }
                }
                let extraArgs = persistedPane.cliType == .claude && appSettings.continueOnRestart ? ["--continue"] : []
                let pane = tab.addPane(name: persistedPane.name, extraArgs: extraArgs, cliType: persistedPane.cliType)
                pane.isPriority = persistedPane.isPriority
                pane.terminalController?.onBell = { [weak appState, weak tab, weak pane] in
                    Task { @MainActor in
                        guard let appState, let tab, let pane else { return }
                        appState.addNotification(
                            paneID: pane.id,
                            paneName: pane.name,
                            tabID: tab.id,
                            tabName: tab.name,
                            isPriority: pane.isPriority
                        )
                    }
                }
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
