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

    nonisolated static func buildClaudeCommand(name: String, settingsPath: String, extraArgs: String) -> String {
        let escapedName = name.replacingOccurrences(of: "'", with: "'\\''")
        let escapedSettings = settingsPath.replacingOccurrences(of: "'", with: "'\\''")
        return "claude --worktree '\(escapedName)' --settings '\(escapedSettings)'\(extraArgs)"
    }

    nonisolated static func isValidWorktreeName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let valid = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return name.unicodeScalars.allSatisfy { valid.contains($0) }
    }

    func hasPaneNamed(_ name: String) -> Bool {
        panes.contains { $0.name == name }
    }

    func addPane(name: String, extraArgs: [String] = [], cliType: CLIType = .claude) {
        let pane = Pane(name: name, tab: self, cliType: cliType)
        if !AgentSessionManagerApp.isUITesting {
            let controller = TerminalController()
            let extra = extraArgs.isEmpty ? "" : " " + extraArgs.joined(separator: " ")
            controller.pendingDirectory = directory.path
            controller.pendingEnvironment = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
            switch cliType {
            case .claude:
                let monitor = StatusLineMonitor(paneID: pane.id)
                monitor.start()
                controller.pendingCommand = Tab.buildClaudeCommand(name: name, settingsPath: monitor.settingsFilePath, extraArgs: extra)
                pane.statusLineMonitor = monitor
            case .codex:
                controller.pendingCommand = "codex\(extra)"
            }
            pane.terminalController = controller
        }
        panes.append(pane)
    }

    func closePane(_ pane: Pane) {
        pane.terminalController?.terminate()
        pane.statusLineMonitor?.stop()
        panes.removeAll { $0.id == pane.id }
    }
}
