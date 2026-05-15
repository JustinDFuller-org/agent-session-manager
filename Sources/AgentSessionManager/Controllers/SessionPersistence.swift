import Foundation

struct PersistedPaneNotification: Codable, Equatable {
    var notificationID: UUID
    var paneID: UUID
    var paneName: String
    var tabID: UUID
    var tabName: String
    var isPriority: Bool
    var timestamp: Date
    var kind: NotificationKind
    var prNumber: Int?
    var prTitle: String?

    enum CodingKeys: String, CodingKey {
        case notificationID, paneID, paneName, tabID, tabName, isPriority, timestamp
        case kind, prNumber, prTitle
    }

    init(
        notificationID: UUID,
        paneID: UUID,
        paneName: String,
        tabID: UUID,
        tabName: String,
        isPriority: Bool,
        timestamp: Date,
        kind: NotificationKind = .terminalBell,
        prNumber: Int? = nil,
        prTitle: String? = nil
    ) {
        self.notificationID = notificationID
        self.paneID = paneID
        self.paneName = paneName
        self.tabID = tabID
        self.tabName = tabName
        self.isPriority = isPriority
        self.timestamp = timestamp
        self.kind = kind
        self.prNumber = prNumber
        self.prTitle = prTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notificationID = try container.decode(UUID.self, forKey: .notificationID)
        paneID = try container.decode(UUID.self, forKey: .paneID)
        paneName = try container.decode(String.self, forKey: .paneName)
        tabID = try container.decode(UUID.self, forKey: .tabID)
        tabName = try container.decode(String.self, forKey: .tabName)
        isPriority = try container.decode(Bool.self, forKey: .isPriority)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        kind = try container.decodeIfPresent(NotificationKind.self, forKey: .kind) ?? .terminalBell
        prNumber = try container.decodeIfPresent(Int.self, forKey: .prNumber)
        prTitle = try container.decodeIfPresent(String.self, forKey: .prTitle)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(notificationID, forKey: .notificationID)
        try container.encode(paneID, forKey: .paneID)
        try container.encode(paneName, forKey: .paneName)
        try container.encode(tabID, forKey: .tabID)
        try container.encode(tabName, forKey: .tabName)
        try container.encode(isPriority, forKey: .isPriority)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(prNumber, forKey: .prNumber)
        try container.encodeIfPresent(prTitle, forKey: .prTitle)
    }
}

struct PersistedSession: Codable {
    var tabs: [PersistedTab]
    var activeTabIndex: Int?
    var pendingNotifications: [PersistedPaneNotification]

    enum CodingKeys: String, CodingKey {
        case tabs
        case activeTabIndex
        case pendingNotifications
    }

    init(tabs: [PersistedTab], activeTabIndex: Int?, pendingNotifications: [PersistedPaneNotification] = []) {
        self.tabs = tabs
        self.activeTabIndex = activeTabIndex
        self.pendingNotifications = pendingNotifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tabs = try container.decode([PersistedTab].self, forKey: .tabs)
        activeTabIndex = try container.decodeIfPresent(Int.self, forKey: .activeTabIndex)
        pendingNotifications =
            try container.decodeIfPresent([PersistedPaneNotification].self, forKey: .pendingNotifications) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tabs, forKey: .tabs)
        try container.encodeIfPresent(activeTabIndex, forKey: .activeTabIndex)
        try container.encode(pendingNotifications, forKey: .pendingNotifications)
    }
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
    var isMerged: Bool
    var worktreeDirectory: String?
    var worktreeIsManaged: Bool
    var profileID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name, cliType, isPriority, isMerged, worktreeDirectory, worktreeIsManaged
        case claudeProcessDirectory
        case profileID
    }

    init(
        id: UUID, name: String, cliType: CLIType, isPriority: Bool = false, isMerged: Bool = false,
        worktreeDirectory: String? = nil, worktreeIsManaged: Bool = false, profileID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.cliType = cliType
        self.isPriority = isPriority
        self.isMerged = isMerged
        self.worktreeDirectory = worktreeDirectory
        self.worktreeIsManaged = worktreeIsManaged
        self.profileID = profileID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cliType = (try? container.decodeIfPresent(CLIType.self, forKey: .cliType)) ?? .claude
        isPriority = (try? container.decodeIfPresent(Bool.self, forKey: .isPriority)) ?? false
        isMerged = (try? container.decodeIfPresent(Bool.self, forKey: .isMerged)) ?? false
        worktreeDirectory =
            try container.decodeIfPresent(String.self, forKey: .worktreeDirectory)
            ?? container.decodeIfPresent(String.self, forKey: .claudeProcessDirectory)
        worktreeIsManaged = (try? container.decodeIfPresent(Bool.self, forKey: .worktreeIsManaged)) ?? false
        profileID = try container.decodeIfPresent(UUID.self, forKey: .profileID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(cliType, forKey: .cliType)
        try container.encode(isPriority, forKey: .isPriority)
        try container.encode(isMerged, forKey: .isMerged)
        try container.encode(worktreeDirectory, forKey: .worktreeDirectory)
        try container.encode(worktreeIsManaged, forKey: .worktreeIsManaged)
        try container.encodeIfPresent(profileID, forKey: .profileID)
    }
}

@MainActor
struct SessionPersistence {
    private static var sessionURL: URL {
        let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = config.appending(path: PersistenceHelpers.appSupportSubdirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "sessions.json")
    }

    static func makePersistedSession(appState: AppState) -> PersistedSession {
        let tabs = appState.tabs.map { tab in
            PersistedTab(
                id: tab.id,
                name: tab.name,
                directory: tab.directory.path,
                panes: tab.panes.compactMap { pane -> PersistedPane? in
                    guard pane.cliType != .shell else { return nil }
                    return PersistedPane(
                        id: pane.id,
                        name: pane.name,
                        cliType: pane.cliType,
                        isPriority: pane.isPriority,
                        isMerged: pane.isMerged,
                        worktreeDirectory: pane.worktreeDirectory?.path,
                        worktreeIsManaged: pane.worktreeIsManaged,
                        profileID: pane.profileID
                    )
                }
            )
        }
        let activeTabIndex = appState.tabs.firstIndex { $0.id == appState.activeTabID }
        let pendingNotifications = appState.notifications.map {
            PersistedPaneNotification(
                notificationID: $0.id,
                paneID: $0.paneID,
                paneName: $0.paneName,
                tabID: $0.tabID,
                tabName: $0.tabName,
                isPriority: $0.isPriority,
                timestamp: $0.timestamp,
                kind: $0.kind,
                prNumber: $0.prNumber,
                prTitle: $0.prTitle
            )
        }
        return PersistedSession(
            tabs: tabs, activeTabIndex: activeTabIndex, pendingNotifications: pendingNotifications)
    }

    static func save(appState: AppState) {
        let session = makePersistedSession(appState: appState)
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: sessionURL)
    }

    static func restore(into appState: AppState, appSettings: AppSettings) {
        guard
            let data = try? Data(contentsOf: sessionURL),
            let session = try? JSONDecoder().decode(PersistedSession.self, from: data)
        else { return }

        var lines: [String] = []
        lines.append("Restoring \(session.tabs.count) tab(s) from \(sessionURL.path)")
        for persistedTab in session.tabs {
            lines.append(
                "  tab: \(persistedTab.name), directory: \(persistedTab.directory), panes: \(persistedTab.panes.count)")
        }
        DebugLogger.shared.logSessionRestore(summary: lines.joined(separator: "\n"))

        for persistedTab in session.tabs {
            guard let dir = URL(string: "file://\(persistedTab.directory)") else { continue }
            let tab = Tab(id: persistedTab.id, name: persistedTab.name, directory: dir)
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
                    worktreeIsManaged: persistedPane.worktreeIsManaged,
                    id: persistedPane.id
                )
                pane.isMerged = persistedPane.isMerged
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

        var restored: [PaneNotification] = []
        var seenPaneIDs = Set<UUID>()
        for pending in session.pendingNotifications {
            guard !seenPaneIDs.contains(pending.paneID) else { continue }
            guard let tab = appState.tabs.first(where: { $0.id == pending.tabID }),
                let pane = tab.panes.first(where: { $0.id == pending.paneID })
            else { continue }
            seenPaneIDs.insert(pending.paneID)
            restored.append(
                PaneNotification(
                    id: pending.notificationID,
                    paneID: pending.paneID,
                    paneName: pane.name,
                    tabID: pending.tabID,
                    tabName: tab.name,
                    isPriority: pending.isPriority,
                    timestamp: pending.timestamp,
                    kind: pending.kind,
                    prNumber: pending.prNumber,
                    prTitle: pending.prTitle
                )
            )
        }
        appState.notifications = restored

        for notification in restored where notification.kind == .prMerged {
            if let tab = appState.tabs.first(where: { $0.id == notification.tabID }),
                let pane = tab.panes.first(where: { $0.id == notification.paneID })
            {
                pane.isMerged = true
            }
        }
    }

    /// Queries GitHub for all restored panes that aren't already marked merged,
    /// and creates notifications for any whose PR has been merged since last run.
    static func checkForMergedPRsAfterRestore(appState: AppState) async {
        guard SettingsPersistence.isPRTrackingEnabled() else { return }
        guard SettingsPersistence.isPRMergedNotificationsEnabled() else { return }

        let candidates: [(pane: Pane, tab: Tab)] = appState.tabs.flatMap { tab in
            tab.panes.compactMap { pane in
                guard !pane.isMerged else { return nil }
                guard pane.worktreeDirectory != nil else { return nil }
                return (pane: pane, tab: tab)
            }
        }
        guard !candidates.isEmpty else { return }

        DebugLogger.shared.log(
            "[pr] startup check: \(candidates.count) candidate pane(s) to check for merged PRs")

        var branchInfos: [PRTrackingCoordinator.BranchInfo] = []
        await withTaskGroup(of: PRTrackingCoordinator.BranchInfo?.self) { group in
            for (pane, _) in candidates {
                guard let cwd = pane.worktreeDirectory?.path else { continue }
                let paneID = pane.id
                group.addTask {
                    async let branchResult = PRTrackingCoordinator.fetchBranch(workingDirectory: cwd)
                    async let ownerRepoResult = PRTrackingCoordinator.fetchOwnerRepo(workingDirectory: cwd)
                    guard let branch = await branchResult,
                        let (owner, repo) = await ownerRepoResult
                    else { return nil }
                    return PRTrackingCoordinator.BranchInfo(
                        paneID: paneID, owner: owner, repo: repo, branch: branch)
                }
            }
            for await info in group {
                if let info { branchInfos.append(info) }
            }
        }

        guard !branchInfos.isEmpty else {
            DebugLogger.shared.log("[pr] startup check: no panes with resolvable branches")
            return
        }

        DebugLogger.shared.log(
            "[pr] startup check: querying GitHub for \(branchInfos.count) branch(es)")

        let results = await PRTrackingCoordinator.checkBranchesForMergedPRs(branches: branchInfos)
        var mergedCount = 0
        for (paneID, pr) in results where pr.state == "merged" {
            guard let (pane, tab) = candidates.first(where: { $0.pane.id == paneID }) else { continue }
            appState.addPRMergedNotification(
                paneID: pane.id,
                paneName: pane.name,
                tabID: tab.id,
                tabName: tab.name,
                prNumber: pr.number,
                prTitle: pr.title
            )
            mergedCount += 1
        }

        DebugLogger.shared.log(
            "[pr] startup check complete: \(mergedCount) merged PR(s) detected")
    }
}
