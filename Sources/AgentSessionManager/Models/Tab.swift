import Foundation
import Observation

struct GitCommandError: Error, LocalizedError, Equatable {
    let arguments: [String]
    let exitCode: Int32
    let stderr: String

    var errorDescription: String? {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let cmd = (["git"] + arguments).joined(separator: " ")
        return "git exited with status \(exitCode): \(cmd)"
    }
}

struct GitWorktreeListEntry: Equatable {
    var path: String
    var branch: String?
}

enum WorktreeResolutionError: Error, LocalizedError, Equatable {
    case emptyRef
    case invalidWorktreeDirectory(String)
    case pathExistsButNotWorktree(String)
    case unsupportedWorktreeLocation(String)
    case refNotFound(String)
    case invalidDerivedName(String)

    var errorDescription: String? {
        switch self {
        case .emptyRef:
            return "Enter a branch name, ref, or existing worktree name."
        case let .invalidWorktreeDirectory(path):
            return "The directory exists but is not a git worktree: \(path)"
        case let .pathExistsButNotWorktree(path):
            return "There is already a non-worktree path at: \(path)"
        case let .unsupportedWorktreeLocation(path):
            return "That branch is already checked out at \(path), which is outside Agent Session Manager’s worktree folder (.agent-session-manager/worktrees). Remove the other worktree or clone in a separate tab."
        case let .refNotFound(ref):
            return "Could not find a git ref named “\(ref)”. Fetch the branch or check the spelling."
        case let .invalidDerivedName(name):
            return "Could not derive a valid worktree folder name from that ref (got “\(name)”). Use only letters, digits, dots, underscores, and dashes in branch names."
        }
    }
}

@Observable
@MainActor
final class Tab: Identifiable {
    /// Relative to the tab’s git repo root. Git worktrees this app creates live here (parallel to Claude’s `.claude/worktrees/`).
    nonisolated static let worktreesRootRelativePath = ".agent-session-manager/worktrees"

    let id: UUID
    var name: String
    var directory: URL
    var panes: [Pane] = []
    var lastActivePaneID: UUID?

    init(name: String, directory: URL) {
        self.id = UUID()
        self.name = name
        self.directory = directory
    }

    var directoryDisplayName: String {
        directory.lastPathComponent
    }

    nonisolated static func worktreeDirectoryURL(repoRoot: URL, name: String) -> URL {
        repoRoot
            .appending(path: ".agent-session-manager", directoryHint: .isDirectory)
            .appending(path: "worktrees", directoryHint: .isDirectory)
            .appending(path: name, directoryHint: .notDirectory)
    }

    /// Path segment passed to `git worktree add` (forward slashes).
    nonisolated static func gitWorktreeAddPath(name: String) -> String {
        "\(worktreesRootRelativePath)/\(name)"
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

    /// Parses `git worktree list --porcelain`.
    nonisolated static func parseWorktreeListPorcelain(_ output: String) -> [GitWorktreeListEntry] {
        var entries: [GitWorktreeListEntry] = []
        var currentPath: String?
        var currentBranch: String?

        func flush() {
            if let p = currentPath {
                entries.append(GitWorktreeListEntry(path: p, branch: currentBranch))
            }
            currentPath = nil
            currentBranch = nil
        }

        for line in output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.isEmpty {
                flush()
                continue
            }
            if line.hasPrefix("worktree ") {
                flush()
                currentPath = String(line.dropFirst("worktree ".count))
            } else if line.hasPrefix("branch ") {
                currentBranch = String(line.dropFirst("branch ".count))
            }
        }
        flush()
        return entries
    }

    nonisolated static func refExpansionCandidates(for raw: String) -> Set<String> {
        var s = Set<String>()
        let r = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty else { return s }
        s.insert(r)
        if r.hasPrefix("refs/") { return s }
        s.insert("refs/heads/\(r)")
        if r.contains("/") {
            s.insert("refs/remotes/\(r)")
        } else {
            s.insert("refs/remotes/origin/\(r)")
        }
        return s
    }

    nonisolated static func refMatches(userRef: String, branchRef: String) -> Bool {
        let u = userRef.trimmingCharacters(in: .whitespacesAndNewlines)
        if branchRef == u { return true }
        if refExpansionCandidates(for: u).contains(branchRef) { return true }
        if branchRef.hasPrefix("refs/heads/") {
            let short = String(branchRef.dropFirst("refs/heads/".count))
            if short == u { return true }
        }
        if branchRef.hasPrefix("refs/remotes/") {
            let rest = String(branchRef.dropFirst("refs/remotes/".count))
            if rest == u { return true }
            if rest.hasSuffix("/\(u)") { return true }
        }
        return false
    }

    nonisolated static func derivedWorktreeName(fromRef ref: String) -> String {
        var s = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["refs/heads/", "refs/remotes/origin/", "refs/remotes/"] {
            if s.hasPrefix(prefix) {
                s = String(s.dropFirst(prefix.count))
                break
            }
        }
        if let idx = s.lastIndex(of: "/") {
            s = String(s[s.index(after: idx)...])
        }
        let out = sanitizeBranchName(s)
        return out.isEmpty ? "worktree" : out
    }

    func hasPaneNamed(_ name: String) -> Bool {
        panes.contains { $0.name == name }
    }

    /// Resolves user input (branch, remote ref, or managed worktree name) to a short worktree name for `claude --worktree`.
    func resolveOrAttachWorktree(userRef raw: String) async throws -> String {
        let ref = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else { throw WorktreeResolutionError.emptyRef }

        if Tab.isValidWorktreeName(ref) {
            let url = Tab.worktreeDirectoryURL(repoRoot: directory, name: ref)
            if FileManager.default.fileExists(atPath: url.path) {
                guard Self.isLinkedGitWorktree(at: url) else {
                    throw WorktreeResolutionError.invalidWorktreeDirectory(url.path)
                }
                return ref
            }
        }

        let listOutput = try await runGitOutput(["worktree", "list", "--porcelain"])
        let entries = Tab.parseWorktreeListPorcelain(listOutput)

        if let found = entries.first(where: { entry in
            guard let b = entry.branch else { return false }
            return Tab.refMatches(userRef: ref, branchRef: b)
        }) {
            if let name = managedWorktreeName(forAbsoluteWorktreePath: found.path) {
                return name
            }
            throw WorktreeResolutionError.unsupportedWorktreeLocation(found.path)
        }

        let targetName = Tab.derivedWorktreeName(fromRef: ref)
        guard Tab.isValidWorktreeName(targetName) else {
            throw WorktreeResolutionError.invalidDerivedName(targetName)
        }
        let targetURL = Tab.worktreeDirectoryURL(repoRoot: directory, name: targetName)
        if FileManager.default.fileExists(atPath: targetURL.path) {
            guard Self.isLinkedGitWorktree(at: targetURL) else {
                throw WorktreeResolutionError.pathExistsButNotWorktree(targetURL.path)
            }
            return targetName
        }

        if !(await refExists(ref)) {
            do {
                try await runGit(["fetch", "origin", ref])
            } catch {
                throw WorktreeResolutionError.refNotFound(ref)
            }
            guard await refExists(ref) else {
                throw WorktreeResolutionError.refNotFound(ref)
            }
        }

        let appConfigRoot = directory.appending(path: ".agent-session-manager", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: appConfigRoot, withIntermediateDirectories: true)
        let rel = Tab.gitWorktreeAddPath(name: targetName)
        do {
            try await runGit(["worktree", "add", rel, ref])
        } catch {
            let listAgain = try await runGitOutput(["worktree", "list", "--porcelain"])
            let again = Tab.parseWorktreeListPorcelain(listAgain)
            if let found = again.first(where: { entry in
                guard let b = entry.branch else { return false }
                return Tab.refMatches(userRef: ref, branchRef: b)
            }) {
                if let name = managedWorktreeName(forAbsoluteWorktreePath: found.path) {
                    return name
                }
                throw WorktreeResolutionError.unsupportedWorktreeLocation(found.path)
            }
            throw error
        }

        return targetName
    }

    private func managedWorktreeName(forAbsoluteWorktreePath path: String) -> String? {
        let workURL = URL(fileURLWithPath: path).standardizedFileURL
        let managedWorktreesBase = Tab.worktreeDirectoryURL(repoRoot: directory, name: "dummy").deletingLastPathComponent().standardizedFileURL
        let basePath = managedWorktreesBase.path
        let p = workURL.path
        guard p.hasPrefix(basePath + "/") else { return nil }
        let relative = String(p.dropFirst(basePath.count + 1))
        guard !relative.isEmpty, !relative.contains("/") else { return nil }
        return relative
    }

    private func refExists(_ ref: String) async -> Bool {
        do {
            _ = try await runGitOutput(["rev-parse", "-q", "--verify", "\(ref)^{commit}"])
            return true
        } catch {
            return false
        }
    }

    nonisolated private static func isLinkedGitWorktree(at url: URL) -> Bool {
        let gitFile = url.appending(path: ".git")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gitFile.path, isDirectory: &isDir) else { return false }
        if isDir.boolValue { return false }
        guard let data = try? Data(contentsOf: gitFile),
              let s = String(data: data, encoding: .utf8),
              s.contains("gitdir:")
        else { return false }
        return true
    }

    private func runGitOutput(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.executableURL = URL(filePath: "/usr/bin/git")
            process.arguments = args
            process.currentDirectoryURL = directory
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.terminationHandler = { p in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                if p.terminationStatus == 0 {
                    continuation.resume(returning: String(data: outData, encoding: .utf8) ?? "")
                } else {
                    let stderr = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: GitCommandError(arguments: args, exitCode: p.terminationStatus, stderr: stderr))
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
            let errPipe = Pipe()
            process.executableURL = URL(filePath: "/usr/bin/git")
            process.arguments = args
            process.currentDirectoryURL = directory
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errPipe
            process.terminationHandler = { p in
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                if p.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: GitCommandError(arguments: args, exitCode: p.terminationStatus, stderr: stderr))
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
