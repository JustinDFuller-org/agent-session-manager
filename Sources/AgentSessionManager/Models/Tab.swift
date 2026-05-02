import Foundation
import Observation

@Observable
@MainActor
final class Tab: Identifiable {
    let id: UUID
    var name: String
    var directory: URL
    var panes: [Pane] = []

    init(name: String, directory: URL) {
        self.id = UUID()
        self.name = name
        self.directory = directory
    }

    var directoryDisplayName: String {
        directory.lastPathComponent
    }

    func addPane(name: String) {
        let pane = Pane(name: name, tab: self)
        let controller = TerminalController()
        let escapedName = name.replacingOccurrences(of: "'", with: "'\\''")
        controller.pendingCommand = "/Users/justinfuller/.local/bin/claude --worktree '\(escapedName)'"
        controller.pendingDirectory = directory.path
        pane.terminalController = controller
        panes.append(pane)
        // startProcess is called by TerminalRepresentable.Coordinator after the view is laid out
    }

    func closePane(_ pane: Pane) {
        pane.terminalController?.terminate()
        panes.removeAll { $0.id == pane.id }
    }
}
