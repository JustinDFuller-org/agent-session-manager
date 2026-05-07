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
        case let .refNotFound(ref):
            return "Could not find a git ref named “\(ref)”. Fetch the branch or check the spelling."
        case let .invalidDerivedName(name):
            return "Could not derive a valid worktree folder name from that ref (got “\(name)”). Use only letters, digits, dots, underscores, and dashes in branch names."
        }
    }
}

/// Result after resolving Git worktree input.
struct ResolvedWorktree: Equatable {
    /// Pane header label.
    var paneTitle: String
    /// The directory where the CLI tool runs.
    var processDirectory: URL
    /// Directory used for duplicate detection and session restore.
    var checkoutURL: URL
    /// Whether this is an existing worktree outside `.agent-session-manager/worktrees/`.
    var isExternalTakeover: Bool
}

@Observable
@MainActor
final class Tab: Identifiable {
    /// Relative to the tab's git repo root. Git worktrees this app creates live here (parallel to Claude's `.claude/worktrees/`).
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

    nonisolated static func buildClaudeCommand(settingsPath: String, extraArgs: String) -> String {
        let escapedSettings = settingsPath.replacingOccurrences(of: "'", with: "'\\''")
        return "claude --settings '\(escapedSettings)'\(extraArgs)"
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

    /// Picks a `git worktree list --porcelain` entry for user input: **directory name** under the repo wins first,
    /// then branch/ref match. Avoids opening the wrong tree when several listings share similar branch names
    /// (e.g. `.claude/worktrees/foo` on branch `worktree-foo` vs `.claude/worktrees/worktree-foo`).
    nonisolated static func preferWorktreeEntry(matchingUserRef ref: String, entries: [GitWorktreeListEntry]) -> GitWorktreeListEntry? {
        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        if let byDirectoryName = entries.first(where: {
            URL(fileURLWithPath: $0.path).lastPathComponent == trimmed
        }) {
            return byDirectoryName
        }
        return entries.first(where: { entry in
            guard let b = entry.branch else { return false }
            return Tab.refMatches(userRef: trimmed, branchRef: b)
        })
    }

    func hasPaneNamed(_ name: String) -> Bool {
        panes.contains { $0.name == name }
    }

    /// Resolved checkout already on disk (`git worktree list` match, app-managed linked tree, etc.); ignores fetch/add.
    private func peekExistingResolvedWorktree(trimmedRef ref: String) async throws -> ResolvedWorktree? {
        if Tab.isValidWorktreeName(ref) {
            let url = Tab.worktreeDirectoryURL(repoRoot: directory, name: ref)
            if FileManager.default.fileExists(atPath: url.path) {
                guard Self.isLinkedGitWorktree(at: url) else {
                    throw WorktreeResolutionError.invalidWorktreeDirectory(url.path)
                }
                return resolvedManaged(shortName: ref)
            }
        }

        let listOutput = try await runGitOutput(["worktree", "list", "--porcelain"])
        let entries = Tab.parseWorktreeListPorcelain(listOutput)

        if let found = Tab.preferWorktreeEntry(matchingUserRef: ref, entries: entries) {
            if let name = managedWorktreeName(forAbsoluteWorktreePath: found.path) {
                return resolvedManaged(shortName: name)
            }
            return resolvedExternalGitListPath(found.path)
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
            return resolvedManaged(shortName: targetName)
        }

        return nil
    }

    /// Resolves user input (branch, remote ref, plain name, or managed worktree name) when attaching or creating Git worktrees in-app.
    /// If the ref does not exist but is a valid worktree name and `defaultBranch` is provided, creates a worktree from that branch.
    func resolveOrAttachWorktree(userRef raw: String, defaultBranch: String? = nil) async throws -> ResolvedWorktree {
        let ref = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else { throw WorktreeResolutionError.emptyRef }

        if let resolved = try await peekExistingResolvedWorktree(trimmedRef: ref) {
            return resolved
        }

        let targetName = Tab.derivedWorktreeName(fromRef: ref)
        guard Tab.isValidWorktreeName(targetName) else {
            throw WorktreeResolutionError.invalidDerivedName(targetName)
        }

        do {
            try await runGit(["fetch", "origin", ref])
        } catch {}

        let remoteRefExists = await refExists("refs/remotes/origin/\(ref)")
        let remoteTargetExists = await refExists("refs/remotes/origin/\(targetName)")
        let localRefExists = await refExists(ref)
        let refIsRemoteOnly = remoteRefExists || remoteTargetExists

        if localRefExists || refIsRemoteOnly {
            let resolvedRef: String
            if await refExists(ref) {
                resolvedRef = ref
            } else if await refExists("refs/remotes/origin/\(ref)") {
                resolvedRef = "refs/remotes/origin/\(ref)"
            } else {
                resolvedRef = "refs/remotes/origin/\(targetName)"
            }

            let appConfigRoot = directory.appending(path: ".agent-session-manager", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: appConfigRoot, withIntermediateDirectories: true)
            let rel = Tab.gitWorktreeAddPath(name: targetName)
            do {
                try await runGit(["worktree", "add", rel, resolvedRef])
            } catch {
                let listAgain = try await runGitOutput(["worktree", "list", "--porcelain"])
                let again = Tab.parseWorktreeListPorcelain(listAgain)
                if let found = Tab.preferWorktreeEntry(matchingUserRef: ref, entries: again) {
                    if let name = managedWorktreeName(forAbsoluteWorktreePath: found.path) {
                        return resolvedManaged(shortName: name)
                    }
                    return resolvedExternalGitListPath(found.path)
                }
                throw error
            }

            return resolvedManaged(shortName: targetName)
        }

        guard let branch = defaultBranch else {
            throw WorktreeResolutionError.refNotFound(ref)
        }

        let appConfigRoot = directory.appending(path: ".agent-session-manager", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: appConfigRoot, withIntermediateDirectories: true)

        if !(await refExists(branch)) {
            try await runGit(["fetch", "origin", branch])
        }

        let rel = Tab.gitWorktreeAddPath(name: targetName)
        let args: [String]
        if await refExists(targetName) {
            args = ["worktree", "add", rel, targetName]
        } else {
            args = ["worktree", "add", "-b", targetName, rel, branch]
        }
        do {
            try await runGit(args)
        } catch {
            let listAgain = try await runGitOutput(["worktree", "list", "--porcelain"])
            let again = Tab.parseWorktreeListPorcelain(listAgain)
            if let found = Tab.preferWorktreeEntry(matchingUserRef: ref, entries: again) {
                if let name = managedWorktreeName(forAbsoluteWorktreePath: found.path) {
                    return resolvedManaged(shortName: name)
                }
                return resolvedExternalGitListPath(found.path)
            }
            throw error
        }

        return resolvedManaged(shortName: targetName)
    }

    private func resolvedManaged(shortName: String) -> ResolvedWorktree {
        let checkout = Tab.worktreeDirectoryURL(repoRoot: directory, name: shortName).standardizedFileURL
        return ResolvedWorktree(paneTitle: shortName, processDirectory: checkout, checkoutURL: checkout, isExternalTakeover: false)
    }

    /// Paths from `git worktree list` are authoritative (includes main checkout with a `.git` directory).
    private func resolvedExternalGitListPath(_ absolutePath: String) -> ResolvedWorktree {
        let url = URL(fileURLWithPath: absolutePath).standardizedFileURL
        var title = url.lastPathComponent
        if title.isEmpty { title = url.path }
        return ResolvedWorktree(paneTitle: title, processDirectory: url, checkoutURL: url, isExternalTakeover: true)
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
        DebugLogger.shared.logGitCommand(args, cwd: directory.path)
        return try await withCheckedThrowingContinuation { continuation in
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
        DebugLogger.shared.logGitCommand(args, cwd: directory.path)
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

    @discardableResult
    func addPane(
        name: String,
        extraArgs: [String] = [],
        cliType: CLIType = .claude,
        worktreeDirectory: URL? = nil,
        worktreeIsManaged: Bool = false
    ) -> Pane {
        if let wd = worktreeDirectory {
            DebugLogger.shared.logWorktreeResolution(userRef: name, result: "dir: \(wd.path), managed: \(worktreeIsManaged)")
        } else {
            DebugLogger.shared.logWorktreeResolution(userRef: name, result: "cwd: \(directory.path)")
        }
        let pane = Pane(name: name, tab: self, cliType: cliType, worktreeDirectory: worktreeDirectory, worktreeIsManaged: worktreeIsManaged)
        if !AgentSessionManagerApp.isUITesting {
            let controller = TerminalController()
            let extra = extraArgs.isEmpty ? "" : " " + extraArgs.joined(separator: " ")
            // Environment evolution:
            // - Pass the full parent environment to child processes. Claude Code relies on
            //   real HOME to find ~/.claude/ for authentication credentials.
            // - Shell-init-related TCC permission prompts are eliminated by the -f flag
            //   passed to zsh in TerminalController (skips all startup files).
            // - Remaining TCC prompts (Documents, Desktop) are one-time decisions from
            //   Claude's startup path scanning. See documentation/features/panes.md.
            let cwd = worktreeDirectory?.path ?? directory.path
            controller.pendingEnvironment = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
            controller.pendingDirectory = cwd
            switch cliType {
            case .claude:
                let monitor = StatusLineMonitor(paneID: pane.id)
                monitor.start()
                controller.pendingCommand = Tab.buildClaudeCommand(
                    settingsPath: monitor.settingsFilePath,
                    extraArgs: extra
                )
                pane.statusLineMonitor = monitor
            case .codex:
                controller.pendingCommand = "codex\(extra)"
            case .cursor:
                controller.pendingCommand = "agent\(extra)"
            case .opencode:
                controller.pendingCommand = "opencode\(extra)"
            }
            pane.terminalController = controller
        }
        panes.append(pane)
        return pane
    }

    func closePane(_ pane: Pane) {
        pane.terminalController?.terminate()
        pane.statusLineMonitor?.stop()
        panes.removeAll { $0.id == pane.id }
    }

    func cleanupWorktree(for pane: Pane) async throws {
        guard pane.worktreeIsManaged, let path = pane.worktreeDirectory else { return }
        guard FileManager.default.fileExists(atPath: path.path) else { return }
        try await runGit(["worktree", "remove", path.path])
    }

    func movePane(from source: IndexSet, to destination: Int) {
        panes.move(fromOffsets: source, toOffset: destination)
    }
}
