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

    nonisolated static func sanitizeBranchName(_ branch: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return branch
            .replacingOccurrences(of: "/", with: "-")
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
    }

    nonisolated static func isValidWorktreeName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let valid = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return name.unicodeScalars.allSatisfy { valid.contains($0) }
    }

    func hasPaneNamed(_ name: String) -> Bool {
        panes.contains { $0.name == name }
    }

    func setupWorktree(name: String, branchName: String) async throws {
        let worktreePath = directory.appending(path: ".tree/\(name)")
        if FileManager.default.fileExists(atPath: worktreePath.path) { return }
        do {
            try await runGit(["worktree", "add", ".tree/\(name)", branchName])
        } catch {
            // Branch already checked out in another worktree — no new worktree needed.
            if await branchAlreadyCheckedOut(branchName) { return }
            try await runGit(["fetch", "origin", branchName])
            try await runGit(["worktree", "add", ".tree/\(name)", branchName])
        }
    }

    private func branchAlreadyCheckedOut(_ branchName: String) async -> Bool {
        let ref = "branch refs/heads/\(branchName)"
        return (try? await runGitOutput(["worktree", "list", "--porcelain"]))?.contains(ref) ?? false
    }

    private func runGitOutput(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(filePath: "/usr/bin/git")
            process.arguments = args
            process.currentDirectoryURL = directory
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { p in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if p.terminationStatus == 0 {
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } else {
                    continuation.resume(throwing: NSError(domain: "git", code: Int(p.terminationStatus)))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func runGit(_ args: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/git")
            process.arguments = args
            process.currentDirectoryURL = directory
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "git", code: Int(p.terminationStatus)))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
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
