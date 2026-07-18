import Foundation
import Observation

enum PaneSetupState {
    case loading
    case failed(error: String)
}

enum Harness: String, Codable, CaseIterable {
    case claude
    case codex
    case cursor
    case opencode
    case shell

    /// User-facing harness types — excludes `.shell` which is an internal session type.
    static var allCases: [Harness] { [.claude, .codex, .cursor, .opencode] }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .opencode: return "OpenCode"
        case .shell: return "Shell"
        }
    }

    var commandDescription: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .cursor: return "agent"
        case .opencode: return "opencode"
        case .shell: return "$SHELL"
        }
    }
}

@Observable
@MainActor
final class Pane: Identifiable {
    let id: UUID
    var name: String
    var harness: Harness
    var worktreeDirectory: URL?
    var worktreeIsManaged: Bool = false
    weak var tab: Tab?
    private(set) var terminalController: TerminalController?
    private(set) var statusLineMonitor: StatusLineMonitor?
    @ObservationIgnored weak var notificationAppState: AppState?
    var isPriority: Bool = false
    var isMerged: Bool = false
    var restartToken = UUID()
    var profileID: UUID?
    var extraArgs: [String] = []
    var setupState: PaneSetupState?
    var uiTestActivityStateOverride: PaneActivityState?
    var opencodeRaceLossRestarted = false
    /// Transient port assigned to an OpenCode pane for its local HTTP API.
    /// Not persisted; a fresh port is allocated on every launch/restart.
    var opencodePort: Int?
    /// OpenCode session ID to resume on relaunch. Persisted across app launches.
    var opencodeSessionID: String?

    init(
        id: UUID = UUID(),
        name: String,
        tab: Tab,
        harness: Harness = .claude,
        worktreeDirectory: URL? = nil,
        worktreeIsManaged: Bool = false,
        profileID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.harness = harness
        self.worktreeDirectory = worktreeDirectory
        self.worktreeIsManaged = worktreeIsManaged
        self.tab = tab
        self.profileID = profileID
    }

    var worktreePath: URL? {
        if let worktreeDirectory { return worktreeDirectory }
        guard let tab else { return nil }
        return Tab.worktreeDirectoryURL(repoRoot: tab.directory, name: name)
    }

    func installTerminalController(_ controller: TerminalController?) {
        guard terminalController !== controller else { return }
        terminalController?.terminalView.onUserInput = nil
        terminalController?.onAttention = nil
        terminalController = controller
        attachTerminalNotificationHandlers()
    }

    func installStatusLineMonitor(_ monitor: StatusLineMonitor) {
        guard statusLineMonitor !== monitor else { return }
        removeStatusLineMonitor()
        statusLineMonitor = monitor
        attachStatusLineNotificationHandlers()
        monitor.start()
    }

    func removeStatusLineMonitor() {
        statusLineMonitor?.stop()
        statusLineMonitor?.onClaudeHookAttention = nil
        statusLineMonitor?.onPRMerged = nil
        statusLineMonitor?.onPRNotMerged = nil
        statusLineMonitor = nil
    }
}
