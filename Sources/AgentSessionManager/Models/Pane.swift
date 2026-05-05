import Foundation
import Observation

enum CLIType: String, Codable, CaseIterable {
    case claude
    case codex

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    var cliCommandDescription: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        }
    }
}

@Observable
@MainActor
final class Pane: Identifiable {
    let id: UUID
    var name: String
    var cliType: CLIType
    weak var tab: Tab?
    var terminalController: TerminalController?
    var statusLineMonitor: StatusLineMonitor?

    var isPriority: Bool = false

    init(name: String, tab: Tab, cliType: CLIType = .claude) {
        self.id = UUID()
        self.name = name
        self.cliType = cliType
        self.tab = tab
    }

    var worktreePath: URL? {
        guard cliType == .claude else { return nil }
        return tab?.directory.appending(path: ".tree/\(name)")
    }
}
