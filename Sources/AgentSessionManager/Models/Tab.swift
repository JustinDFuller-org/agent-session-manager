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
        case .invalidWorktreeDirectory(let path):
            return "The directory exists but is not a git worktree: \(path)"
        case .pathExistsButNotWorktree(let path):
            return "There is already a non-worktree path at: \(path)"
        case .refNotFound(let ref):
            return "Could not find a git ref named “\(ref)”. Fetch the branch or check the spelling."
        case .invalidDerivedName(let name):
            return
                "Could not derive a valid worktree folder name from that ref (got “\(name)”). Use only letters, digits, dots, underscores, and dashes in branch names."
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

    init(id: UUID = UUID(), name: String, directory: URL) {
        self.id = id
        self.name = name
        self.directory = directory
    }

    var hasRunningPane: Bool {
        panes.contains {
            if case .running = $0.terminalController?.processState { return true }
            return false
        }
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
        return
            branch
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

    /// Returns `extraArgs` prepended with `--name '<tabName>/<paneName>'` when auto-naming is
    /// enabled and neither `--name` nor `-n` is already present in `extraArgs`.
    nonisolated static func applyAutoSessionName(
        tabName: String,
        paneName: String,
        extraArgs: [String],
        harness: Harness,
        enabled: Bool
    ) -> [String] {
        guard enabled, harness == .claude else { return extraArgs }
        guard !extraArgs.contains("--name"), !extraArgs.contains("-n") else { return extraArgs }
        let raw = "\(tabName)/\(paneName)"
        let escaped = raw.replacingOccurrences(of: "'", with: "'\\''")
        return ["--name", "'\(escaped)'"] + extraArgs
    }

    /// Parses `git worktree list --porcelain`.
    nonisolated static func parseWorktreeListPorcelain(_ output: String) -> [GitWorktreeListEntry] {
        var entries: [GitWorktreeListEntry] = []
        var currentPath: String?
        var currentBranch: String?

        func flush() {
            if let path = currentPath {
                entries.append(GitWorktreeListEntry(path: path, branch: currentBranch))
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

    nonisolated static func refMatches(userRef: String, branchRef: String) -> Bool {
        let trimmedUserRef = userRef.trimmingCharacters(in: .whitespacesAndNewlines)
        if branchRef == trimmedUserRef { return true }
        var refs = Set([trimmedUserRef])
        if !trimmedUserRef.hasPrefix("refs/") {
            refs.insert("refs/heads/\(trimmedUserRef)")
            if trimmedUserRef.contains("/") {
                refs.insert("refs/remotes/\(trimmedUserRef)")
            } else {
                refs.insert("refs/remotes/origin/\(trimmedUserRef)")
            }
        }
        if refs.contains(branchRef) { return true }
        if branchRef.hasPrefix("refs/heads/") {
            let short = String(branchRef.dropFirst("refs/heads/".count))
            if short == trimmedUserRef { return true }
        }
        if branchRef.hasPrefix("refs/remotes/") {
            let rest = String(branchRef.dropFirst("refs/remotes/".count))
            if rest == trimmedUserRef { return true }
            if rest.hasSuffix("/\(trimmedUserRef)") { return true }
        }
        return false
    }

    nonisolated static func derivedWorktreeName(fromRef ref: String) -> String {
        var name = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["refs/heads/", "refs/remotes/origin/", "refs/remotes/"] where name.hasPrefix(prefix) {
            name = String(name.dropFirst(prefix.count))
            break
        }
        if let idx = name.lastIndex(of: "/") {
            name = String(name[name.index(after: idx)...])
        }
        let out = sanitizeBranchName(name)
        return out.isEmpty ? "worktree" : out
    }

    /// Picks a `git worktree list --porcelain` entry for user input: **directory name** under the repo wins first,
    /// then branch/ref match. Avoids opening the wrong tree when several listings share similar branch names
    /// (e.g. `.claude/worktrees/foo` on branch `worktree-foo` vs `.claude/worktrees/worktree-foo`).
    nonisolated static func preferWorktreeEntry(
        matchingUserRef ref: String, entries: [GitWorktreeListEntry]
    ) -> GitWorktreeListEntry? {
        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        if let byDirectoryName = entries.first(where: {
            URL(fileURLWithPath: $0.path).lastPathComponent == trimmed
        }) {
            return byDirectoryName
        }
        return entries.first(where: { entry in
            guard let branch = entry.branch else { return false }
            return Tab.refMatches(userRef: trimmed, branchRef: branch)
        })
    }

    /// Resolves user input (branch, remote ref, plain name, or managed worktree name) when attaching or creating Git worktrees in-app.
    /// If the ref does not exist but is a valid worktree name and `defaultBranch` is provided, creates a worktree from that branch.
    func resolveOrAttachWorktree(
        userRef raw: String,
        defaultBranch: String? = nil,
        baseRef: WorktreeBaseRef = .fresh
    ) async throws -> ResolvedWorktree {
        let ref = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else { throw WorktreeResolutionError.emptyRef }

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

        let initialTargetName = Tab.derivedWorktreeName(fromRef: ref)
        guard Tab.isValidWorktreeName(initialTargetName) else {
            throw WorktreeResolutionError.invalidDerivedName(initialTargetName)
        }
        let targetURL = Tab.worktreeDirectoryURL(repoRoot: directory, name: initialTargetName)
        if FileManager.default.fileExists(atPath: targetURL.path) {
            guard Self.isLinkedGitWorktree(at: targetURL) else {
                throw WorktreeResolutionError.pathExistsButNotWorktree(targetURL.path)
            }
            return resolvedManaged(shortName: initialTargetName)
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

        let startingRef: String
        switch baseRef {
        case .fresh:
            do {
                try await runGit(["fetch", "origin", branch])
                startingRef = "origin/\(branch)"
            } catch {
                if await refExists(branch) {
                    startingRef = branch
                } else {
                    throw WorktreeResolutionError.refNotFound(branch)
                }
            }
        case .head:
            startingRef = "HEAD"
        }

        let rel = Tab.gitWorktreeAddPath(name: targetName)
        let args: [String]
        if await refExists(targetName) {
            args = ["worktree", "add", rel, targetName]
        } else {
            args = ["worktree", "add", "-b", targetName, rel, startingRef]
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
        return ResolvedWorktree(
            paneTitle: shortName, processDirectory: checkout, checkoutURL: checkout, isExternalTakeover: false)
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
        let managedWorktreesBase = Tab.worktreeDirectoryURL(repoRoot: directory, name: "dummy")
            .deletingLastPathComponent().standardizedFileURL
        let basePath = managedWorktreesBase.path
        let worktreePath = workURL.path
        guard worktreePath.hasPrefix(basePath + "/") else { return nil }
        let relative = String(worktreePath.dropFirst(basePath.count + 1))
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
            let gitFileContent = String(data: data, encoding: .utf8),
            gitFileContent.contains("gitdir:")
        else { return false }
        return true
    }

    private func runGitOutput(_ args: [String]) async throws -> String {
        let cwd = directory.path
        return try await TracingService.shared.withSpan(
            "tab.git.command",
            attributes: ["cwd": cwd, "args": args.joined(separator: " ")]
        ) {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.executableURL = URL(filePath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = self.directory
                process.standardOutput = outPipe
                process.standardError = errPipe
                process.terminationHandler = { proc in
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    if proc.terminationStatus == 0 {
                        continuation.resume(returning: String(data: outData, encoding: .utf8) ?? "")
                    } else {
                        let stderr = String(data: errData, encoding: .utf8) ?? ""
                        continuation.resume(
                            throwing: GitCommandError(
                                arguments: args, exitCode: proc.terminationStatus, stderr: stderr))
                    }
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runGit(_ args: [String]) async throws {
        let cwd = directory.path
        try await TracingService.shared.withSpan(
            "tab.git.command",
            attributes: ["cwd": cwd, "args": args.joined(separator: " ")]
        ) {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                let errPipe = Pipe()
                process.executableURL = URL(filePath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = self.directory
                process.standardOutput = FileHandle.nullDevice
                process.standardError = errPipe
                process.terminationHandler = { proc in
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderr = String(data: errData, encoding: .utf8) ?? ""
                    if proc.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(
                            throwing: GitCommandError(
                                arguments: args, exitCode: proc.terminationStatus, stderr: stderr))
                    }
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    func addPane(
        name: String,
        extraArgs: [String] = [],
        harness: Harness = .claude,
        worktreeDirectory: URL? = nil,
        worktreeIsManaged: Bool = false,
        id: UUID? = nil,
        extraEnvVars: [String: String] = [:],
        profileID: UUID? = nil,
        statusLineConfigOverride: StatusLineConfig? = nil,
        appSettings: AppSettings? = nil
    ) -> Pane {
        let paneID = id ?? UUID()
        if let wd = worktreeDirectory {
            TracingService.shared.record(
                "tab.worktree.resolved",
                attributes: [
                    "user_ref": name,
                    "result": "dir: \(wd.path)",
                    "path": wd.path,
                    "pane.name": name,
                    "pane.id": paneID.uuidString,
                    "tab.id": self.id.uuidString,
                    "tab.name": self.name,
                ])
        }
        TracingService.shared.record(
            "tab.pane.added",
            attributes: [
                "pane.name": name,
                "pane.id": paneID.uuidString,
                "tab.id": self.id.uuidString,
                "tab.name": self.name,
            ])
        let pane = Pane(
            id: paneID,
            name: name,
            tab: self,
            harness: harness,
            worktreeDirectory: worktreeDirectory,
            worktreeIsManaged: worktreeIsManaged,
            profileID: profileID
        )
        pane.extraArgs = extraArgs
        let cwd = worktreeDirectory?.path ?? directory.path

        if harness != .shell {
            let monitor = StatusLineMonitor(
                paneID: pane.id, paneName: pane.name,
                workingDirectory: cwd, harness: harness, processStartTime: Date(),
                tabID: self.id, tabName: self.name)
            pane.installStatusLineMonitor(monitor)
        }

        if !AgentSessionManagerApp.isUITesting {
            let controller = TerminalController()
            let extra = extraArgs.isEmpty ? "" : " " + extraArgs.joined(separator: " ")
            controller.pendingEnvironment = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
            controller.pendingDirectory = cwd
            controller.pendingShell = appSettings.map { ShellResolver.resolved($0) }

            switch harness {
            case .shell:
                controller.pendingCommand = nil
            case .claude:
                if !extraEnvVars.isEmpty {
                    controller.pendingEnvironment =
                        (controller.pendingEnvironment ?? [])
                        + extraEnvVars.map { "\($0.key)=\($0.value)" }
                }
                controller.pendingCommand = Tab.buildClaudeCommand(
                    settingsPath: pane.statusLineMonitor!.settingsFilePath,
                    extraArgs: extra
                )
            case .codex:
                controller.pendingCommand = "codex\(extra)"
            case .cursor:
                controller.pendingEnvironment =
                    (controller.pendingEnvironment ?? [])
                    + ["AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)"]
                controller.pendingCommand = "agent\(extra)"
            }
            pane.installTerminalController(controller)
            controller.terminalView.telemetryTabName = self.name
            controller.terminalView.telemetryTabUUID = self.id
            controller.terminalView.telemetryPaneName = pane.name
            controller.terminalView.telemetryPaneUUID = pane.id
        }
        panes.append(pane)
        return pane
    }

    /// Restarts a pane by replacing its terminal controller with a new one running the same command.
    func restartPane(_ pane: Pane) {
        guard let old = pane.terminalController else { return }
        let new = TerminalController()
        new.pendingCommand = old.pendingCommand
        new.pendingDirectory = old.pendingDirectory
        new.pendingEnvironment = old.pendingEnvironment
        new.pendingShell = old.pendingShell
        old.terminate()
        pane.installTerminalController(new)
        pane.restartToken = UUID()
    }

    /// Refreshes a pane with either its existing command or new CLI settings.
    func refreshPane(
        _ pane: Pane,
        extraArgs: [String]? = nil,
        harness: Harness? = nil,
        extraEnvVars: [String: String] = [:],
        appSettings: AppSettings? = nil
    ) {
        if let extraArgs, let harness {
            guard let old = pane.terminalController else { return }
            old.terminate()
            let extra = extraArgs.isEmpty ? "" : " " + extraArgs.joined(separator: " ")
            let cwd = pane.worktreeDirectory?.path ?? directory.path
            let controller = TerminalController()
            controller.pendingEnvironment = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
            controller.pendingDirectory = cwd
            controller.pendingShell = appSettings.map { ShellResolver.resolved($0) }

            switch harness {
            case .shell:
                controller.pendingCommand = nil
                pane.removeStatusLineMonitor()
            case .claude:
                let monitor = StatusLineMonitor(
                    paneID: pane.id, paneName: pane.name,
                    workingDirectory: cwd, harness: harness, processStartTime: Date(),
                    tabID: self.id, tabName: self.name)
                pane.installStatusLineMonitor(monitor)
                if !extraEnvVars.isEmpty {
                    controller.pendingEnvironment =
                        (controller.pendingEnvironment ?? [])
                        + extraEnvVars.map { "\($0.key)=\($0.value)" }
                }
                controller.pendingCommand = Tab.buildClaudeCommand(
                    settingsPath: monitor.settingsFilePath, extraArgs: extra)
            case .codex:
                let monitor = StatusLineMonitor(
                    paneID: pane.id, paneName: pane.name,
                    workingDirectory: cwd, harness: harness, processStartTime: Date(),
                    tabID: self.id, tabName: self.name)
                pane.installStatusLineMonitor(monitor)
                controller.pendingCommand = "codex\(extra)"
            case .cursor:
                let monitor = StatusLineMonitor(
                    paneID: pane.id, paneName: pane.name,
                    workingDirectory: cwd, harness: harness, processStartTime: Date(),
                    tabID: self.id, tabName: self.name)
                pane.installStatusLineMonitor(monitor)
                controller.pendingEnvironment =
                    (controller.pendingEnvironment ?? [])
                    + ["AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)"]
                controller.pendingCommand = "agent\(extra)"
            }

            pane.harness = harness
            pane.installTerminalController(controller)
            pane.restartToken = UUID()
            return
        }

        guard let old = pane.terminalController else { return }
        let new = TerminalController()
        new.pendingCommand = Tab.injectContinueFlag(into: old.pendingCommand ?? "")
        new.pendingDirectory = old.pendingDirectory
        new.pendingEnvironment = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
        new.pendingShell = old.pendingShell
        old.terminate()
        let cwd = new.pendingDirectory ?? directory.path
        let monitor = StatusLineMonitor(
            paneID: pane.id, paneName: pane.name,
            workingDirectory: cwd, harness: pane.harness, processStartTime: Date(),
            tabID: self.id, tabName: self.name)
        pane.installStatusLineMonitor(monitor)
        if pane.harness == .claude {
            let extra = Tab.extractExtraArgs(from: old.pendingCommand ?? "")
            let continued = Tab.injectContinueFlagIntoArgs(extra)
            new.pendingCommand = Tab.buildClaudeCommand(settingsPath: monitor.settingsFilePath, extraArgs: continued)
        }
        pane.installTerminalController(new)
        pane.restartToken = UUID()
    }

    /// Replaces a pane's terminal with a plain shell session in the same working directory.
    func openShellInPane(_ pane: Pane) {
        guard let old = pane.terminalController else { return }
        let new = TerminalController()
        new.pendingCommand = nil
        new.pendingDirectory = old.pendingDirectory
        new.pendingEnvironment = old.pendingEnvironment
        new.pendingShell = old.pendingShell
        old.terminate()
        pane.removeStatusLineMonitor()
        pane.harness = .shell
        pane.installTerminalController(new)
        pane.restartToken = UUID()
    }

    /// Opens a new plain shell pane in this tab, in the same working directory as the active pane.
    func openShellPane(activePane: Pane?, appSettings: AppSettings? = nil) {
        let cwd = activePane?.terminalController?.pendingDirectory
        addPane(
            name: "shell",
            harness: .shell,
            worktreeDirectory: cwd.map { URL(filePath: $0) },
            appSettings: appSettings
        )
    }

    func closePane(_ pane: Pane) {
        pane.terminalController?.terminate()
        pane.installTerminalController(nil)
        pane.removeStatusLineMonitor()
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

extension Tab {
    /// Appends `--continue` to a command string if not already present.
    nonisolated static func injectContinueFlag(into command: String) -> String {
        if command.contains("--continue") { return command }
        return command + " --continue"
    }

    /// Extracts the extra args portion from a Claude command string (everything after `--settings '...'`).
    nonisolated static func extractExtraArgs(from command: String) -> String {
        guard let settingsRange = command.range(of: "--settings ") else {
            let parts = command.split(separator: " ", maxSplits: 1)
            return parts.count > 1 ? " " + parts[1] : ""
        }
        var idx = settingsRange.upperBound
        if idx < command.endIndex && command[idx] == "'" {
            idx = command.index(after: idx)
            while idx < command.endIndex {
                if command[idx] == "'" {
                    if command.index(after: idx) < command.endIndex
                        && command[command.index(after: idx)] == "\\"
                    {
                        idx = command.index(idx, offsetBy: 4, limitedBy: command.endIndex) ?? command.endIndex
                        continue
                    }
                    idx = command.index(after: idx)
                    break
                }
                idx = command.index(after: idx)
            }
        }
        if idx < command.endIndex {
            return String(command[idx...])
        }
        return ""
    }

    /// Injects `--continue` into an extra-args string if not already present.
    nonisolated static func injectContinueFlagIntoArgs(_ args: String) -> String {
        if args.contains("--continue") { return args }
        return args + " --continue"
    }
}

extension Tab {
    /// Creates a pane with a loading overlay; terminal setup is deferred to `completeSetup`.
    @discardableResult
    func addPaneWithLoadingState(
        name: String,
        harness: Harness = .claude,
        worktreeIsManaged: Bool = false,
        profileID: UUID? = nil
    ) -> Pane {
        TracingService.shared.record(
            "tab.pane.added",
            attributes: [
                "pane.name": name,
                "tab.name": self.name,
            ])
        let pane = Pane(
            name: name,
            tab: self,
            harness: harness,
            worktreeIsManaged: worktreeIsManaged,
            profileID: profileID
        )
        pane.setupState = .loading
        panes.append(pane)
        return pane
    }

    /// Finishes setup of a pane created by `addPaneWithLoadingState`: wires the terminal controller
    /// and clears the loading state.
    func completeSetup(
        for pane: Pane,
        resolved: ResolvedWorktree,
        managed: Bool,
        effectiveExtraArgs: [String],
        extraEnvVars: [String: String],
        statusLineConfigOverride: StatusLineConfig?,
        appSettings: AppSettings? = nil
    ) {
        pane.name = resolved.paneTitle
        pane.worktreeDirectory = resolved.processDirectory
        pane.worktreeIsManaged = managed
        pane.extraArgs = effectiveExtraArgs

        TracingService.shared.record(
            "tab.worktree.resolved",
            attributes: [
                "user_ref": pane.name,
                "result": "dir: \(resolved.processDirectory.path)",
                "path": resolved.processDirectory.path,
                "pane.name": pane.name,
                "pane.id": pane.id.uuidString,
                "tab.id": self.id.uuidString,
                "tab.name": self.name,
            ])

        let cwd = resolved.processDirectory.path

        if pane.harness != .shell {
            let monitor = StatusLineMonitor(
                paneID: pane.id, paneName: pane.name,
                workingDirectory: cwd, harness: pane.harness, processStartTime: Date(),
                tabID: self.id, tabName: self.name)
            pane.installStatusLineMonitor(monitor)
        }

        if !AgentSessionManagerApp.isUITesting {
            let controller = TerminalController()
            let extra = effectiveExtraArgs.isEmpty ? "" : " " + effectiveExtraArgs.joined(separator: " ")
            controller.pendingEnvironment = ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" }
            controller.pendingDirectory = cwd
            controller.pendingShell = appSettings.map { ShellResolver.resolved($0) }

            switch pane.harness {
            case .shell:
                controller.pendingCommand = nil
            case .claude:
                if !extraEnvVars.isEmpty {
                    controller.pendingEnvironment =
                        (controller.pendingEnvironment ?? [])
                        + extraEnvVars.map { "\($0.key)=\($0.value)" }
                }
                controller.pendingCommand = Tab.buildClaudeCommand(
                    settingsPath: pane.statusLineMonitor!.settingsFilePath,
                    extraArgs: extra
                )
            case .codex:
                controller.pendingCommand = "codex\(extra)"
            case .cursor:
                controller.pendingEnvironment =
                    (controller.pendingEnvironment ?? [])
                    + ["AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)"]
                controller.pendingCommand = "agent\(extra)"
            }
            controller.terminalView.telemetryTabName = self.name
            controller.terminalView.telemetryTabUUID = self.id
            controller.terminalView.telemetryPaneName = pane.name
            controller.terminalView.telemetryPaneUUID = pane.id
            pane.installTerminalController(controller)
        }
        pane.setupState = nil
    }
}
