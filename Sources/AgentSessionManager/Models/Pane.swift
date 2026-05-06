import Foundation
import Observation

enum CLIType: String, Codable, CaseIterable {
    case claude
    case codex
    case cursor

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }

    var cliCommandDescription: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .cursor: return "agent"
        }
    }
}

@Observable
@MainActor
final class Pane: Identifiable {
    let id: UUID
    var name: String
    var cliType: CLIType
    /// When set, Claude runs in this directory without `--worktree` (reuse path from `git worktree list`).
    var claudeDirectoryOverride: URL?
    weak var tab: Tab?
    var terminalController: TerminalController?
    var statusLineMonitor: StatusLineMonitor?
    var isPriority: Bool = false

    init(name: String, tab: Tab, cliType: CLIType = .claude, claudeDirectoryOverride: URL? = nil) {
        self.id = UUID()
        self.name = name
        self.cliType = cliType
        self.claudeDirectoryOverride = claudeDirectoryOverride
        self.tab = tab
    }

    var worktreePath: URL? {
        guard cliType == .claude else { return nil }
        guard let tab else { return nil }
        if let claudeDirectoryOverride { return claudeDirectoryOverride }
        return Tab.worktreeDirectoryURL(repoRoot: tab.directory, name: name)
    }

    var worktreeIsManaged: Bool {
        guard cliType == .claude, claudeDirectoryOverride == nil, let tab else { return false }
        let path = Tab.worktreeDirectoryURL(repoRoot: tab.directory, name: name)
        return FileManager.default.fileExists(atPath: path.path)
    }
}
