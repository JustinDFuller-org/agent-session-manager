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

/// Result after resolving Git worktree input (attached checkout path and Claude launch semantics).
struct ResolvedWorktree: Equatable {
    /// Pane header label (short name under `.agent-session-manager/worktrees/`, or worktree folder name / repo name).
    var paneTitle: String
    /// When non-`nil`, the terminal runs Claude in this directory without passing `--worktree`.
    var claudeProcessDirectory: URL?
    /// Directory used for duplicate detection and session restore.
    var checkoutURL: URL
}

/// How the New Pane sheet should proceed for Claude from a single user string.
enum ClaudePaneIntent: Equatable {
    /// An existing checkout on disk matched; show confirmation before attaching.
    case reuse(confirmationMessage: String, rawInput: String, resolved: ResolvedWorktree)
    /// Run `resolveOrAttachWorktree` (fetch / `git worktree add` under app-managed paths as needed).
    case resolveViaApp(rawInput: String)
    /// New session name not tied to an existing git ref; pass `--worktree` to Claude.
    case claudeWorktreeFlag(name: String)
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

    /// When `worktreeName` is `nil`, runs `claude` in the process working directory without `--worktree` (existing checkout).
    nonisolated static func buildClaudeCommand(worktreeName: String?, settingsPath: String, extraArgs: String) -> String {
        let escapedSettings = settingsPath.replacingOccurrences(of: "'", with: "'\\''")
        let settingsFlag = " --settings '\(escapedSettings)'"
        if let name = worktreeName {
            let escapedName = name.replacingOccurrences(of: "'", with: "'\\''")
            return "claude --worktree '\(escapedName)'\(settingsFlag)\(extraArgs)"
        }
        return "claude\(settingsFlag)\(extraArgs)"
    }

    nonisolated static func buildClaudeCommand(name: String, settingsPath: String, extraArgs: String) -> String {
        buildClaudeCommand(worktreeName: name, settingsPath: settingsPath, extraArgs: extraArgs)
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

    /// Classifies Claude New Pane input (no fetch or `worktree add`). Throws the same preliminary errors as resolving.
    ///
    /// A short branch name that exists **only** on the remote and is not fetched yet—while `origin/<name>`
    /// is not reachable via `git rev-parse`—may classify as `.claudeWorktreeFlag` until refs are fetched.
    func classifyClaudePaneIntent(userRef raw: String) async throws -> ClaudePaneIntent {
        let ref = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else { throw WorktreeResolutionError.emptyRef }

        if let resolved = try await peekExistingResolvedWorktree(trimmedRef: ref) {
            return .reuse(
                confirmationMessage: Self.reuseConfirmationMessage(for: resolved),
                rawInput: ref,
                resolved: resolved
            )
        }

        // Ref-shaped input or any token that resolves to a commit goes through Git (create managed worktree etc.).
        if !Tab.isValidWorktreeName(ref) {
            return .resolveViaApp(rawInput: ref)
        }
        if await refExists(ref) {
            return .resolveViaApp(rawInput: ref)
        }
        return .claudeWorktreeFlag(name: ref)
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

    nonisolated private static func reuseConfirmationMessage(for resolved: ResolvedWorktree) -> String {
        let path = resolved.checkoutURL.path
        if resolved.claudeProcessDirectory != nil {
            return "A checkout for this repo already exists on disk:\n\(path)\n\nOpen Claude there?"
        }
        return "The app-managed worktree already exists:\n\(path)\n\nContinue?"
    }

    /// Resolves user input (branch, remote ref, or managed worktree name) when attaching or creating Git worktrees in-app.
    func resolveOrAttachWorktree(userRef raw: String) async throws -> ResolvedWorktree {
        let ref = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else { throw WorktreeResolutionError.emptyRef }

        if let resolved = try await peekExistingResolvedWorktree(trimmedRef: ref) {
            return resolved
        }

        let targetName = Tab.derivedWorktreeName(fromRef: ref)
        guard Tab.isValidWorktreeName(targetName) else {
            throw WorktreeResolutionError.invalidDerivedName(targetName)
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
        return ResolvedWorktree(paneTitle: shortName, claudeProcessDirectory: nil, checkoutURL: checkout)
    }

    /// Paths from `git worktree list` are authoritative (includes main checkout with a `.git` directory).
    private func resolvedExternalGitListPath(_ absolutePath: String) -> ResolvedWorktree {
        let url = URL(fileURLWithPath: absolutePath).standardizedFileURL
        var title = url.lastPathComponent
        if title.isEmpty { title = url.path }
        return ResolvedWorktree(paneTitle: title, claudeProcessDirectory: url, checkoutURL: url)
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

    func addPane(
        name: String,
        extraArgs: [String] = [],
        cliType: CLIType = .claude,
        claudeDirectoryOverride: URL? = nil
    ) {
        let pane = Pane(name: name, tab: self, cliType: cliType, claudeDirectoryOverride: claudeDirectoryOverride)
        if !AgentSessionManagerApp.isUITesting {
            let controller = TerminalController()
            let extra = extraArgs.isEmpty ? "" : " " + extraArgs.joined(separator: " ")
            controller.pendingEnvironment = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
            switch cliType {
            case .claude:
                let monitor = StatusLineMonitor(paneID: pane.id)
                monitor.start()
                if let override = claudeDirectoryOverride {
                    controller.pendingDirectory = override.path
                    controller.pendingCommand = Tab.buildClaudeCommand(
                        worktreeName: nil,
                        settingsPath: monitor.settingsFilePath,
                        extraArgs: extra
                    )
                } else {
                    controller.pendingDirectory = directory.path
                    controller.pendingCommand = Tab.buildClaudeCommand(
                        worktreeName: name,
                        settingsPath: monitor.settingsFilePath,
                        extraArgs: extra
                    )
                }
                pane.statusLineMonitor = monitor
            case .codex:
                controller.pendingDirectory = directory.path
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
