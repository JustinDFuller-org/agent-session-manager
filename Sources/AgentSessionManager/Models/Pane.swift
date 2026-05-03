import Foundation
import Observation

@Observable
@MainActor
final class Pane: Identifiable {
    let id: UUID
    var name: String
    weak var tab: Tab?
    var terminalController: TerminalController?
    var statusLineMonitor: StatusLineMonitor?

    init(name: String, tab: Tab) {
        self.id = UUID()
        self.name = name
        self.tab = tab
    }

    var worktreePath: URL? {
        tab?.directory.appending(path: ".tree/\(name)")
    }
}
