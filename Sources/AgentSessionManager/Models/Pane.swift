import Foundation
import Observation

enum PaneSetupState {
    case loading
    case failed(error: String)
}

enum CLIType: String, Codable, CaseIterable {
    case claude
    case codex
    case cursor
    case opencode
    case shell

    /// User-facing tool types — excludes `.shell` which is an internal session type.
    static var allCases: [CLIType] { [.claude, .codex, .cursor, .opencode] }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .opencode: return "OpenCode"
        case .shell: return "Shell"
        }
    }

    var cliCommandDescription: String {
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
    var cliType: CLIType
    var worktreeDirectory: URL?
    var worktreeIsManaged: Bool = false
    weak var tab: Tab?
    var terminalController: TerminalController?
    var statusLineMonitor: StatusLineMonitor?
    var isPriority: Bool = false
    var isMerged: Bool = false
    var restartToken = UUID()
    var profileID: UUID?
    var extraArgs: [String] = []
    var setupState: PaneSetupState?

    init(
        id: UUID = UUID(),
        name: String,
        tab: Tab,
        cliType: CLIType = .claude,
        worktreeDirectory: URL? = nil,
        worktreeIsManaged: Bool = false,
        profileID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.cliType = cliType
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
}
