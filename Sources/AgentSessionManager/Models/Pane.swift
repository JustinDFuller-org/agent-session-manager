import Foundation
import Observation

enum CLIType: String, Codable, CaseIterable {
    case claude
    case codex
    case cursor
    case opencode

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .opencode: return "OpenCode"
        }
    }

    var cliCommandDescription: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .cursor: return "agent"
        case .opencode: return "opencode"
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

    init(name: String, tab: Tab, cliType: CLIType = .claude, worktreeDirectory: URL? = nil, worktreeIsManaged: Bool = false) {
        self.id = UUID()
        self.name = name
        self.cliType = cliType
        self.worktreeDirectory = worktreeDirectory
        self.worktreeIsManaged = worktreeIsManaged
        self.tab = tab
    }

    var worktreePath: URL? {
        if let worktreeDirectory { return worktreeDirectory }
        guard let tab else { return nil }
        return Tab.worktreeDirectoryURL(repoRoot: tab.directory, name: name)
    }
}
