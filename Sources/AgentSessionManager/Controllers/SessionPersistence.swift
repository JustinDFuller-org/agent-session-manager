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
                panes: tab.panes.map { PersistedPane(id: $0.id, name: $0.name) }
            )
        }
        let activeTabIndex = appState.tabs.firstIndex { $0.id == appState.activeTabID }
        let session = PersistedSession(tabs: tabs, activeTabIndex: activeTabIndex)
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: sessionURL)
    }

    static func restore(into appState: AppState) {
        guard
            let data = try? Data(contentsOf: sessionURL),
            let session = try? JSONDecoder().decode(PersistedSession.self, from: data)
        else { return }

        for persistedTab in session.tabs {
            guard let dir = URL(string: "file://\(persistedTab.directory)") else { continue }
            let tab = Tab(name: persistedTab.name, directory: dir)
            for persistedPane in persistedTab.panes {
                let worktreePath = dir.appending(path: ".tree/\(persistedPane.name)")
                guard FileManager.default.fileExists(atPath: worktreePath.path) else { continue }
                tab.addPane(name: persistedPane.name)
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
