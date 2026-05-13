import Foundation

/// Provides status line data for Cursor CLI panes by combining two data sources:
///   1. A Cursor hooks file (`afterAgentResponse`) that pipes model info to a per-pane temp file
///   2. Periodic git/duration/version polling (same as `ToolAgnosticDataProvider`)
///
/// The hooks-based model detection requires a user-level `~/.cursor/hooks.json` with an
/// `afterAgentResponse` hook that writes stdin to a file keyed by the `AGENT_SESSION_MANAGER_PANE_ID`
/// environment variable. `CursorHookSetup` handles creating/updating this file.
final class CursorDataProvider: StatusLineDataProvider {
    var onUpdate: ((StatusLineData) -> Void)?

    let workingDirectory: String
    let processStartTime: Date
    let paneID: UUID
    let hookOutputFilePath: String

    private var refreshTimer: Timer?
    private var versionFetchedVersion: String?
    private var hookSource: DispatchSourceFileSystemObject?
    private var lastHookModel: StatusLineData.Model?

    init(workingDirectory: String, paneID: UUID, processStartTime: Date) {
        self.workingDirectory = workingDirectory
        self.paneID = paneID
        self.processStartTime = processStartTime
        self.hookOutputFilePath =
            NSTemporaryDirectory() + "agent-session-manager-cursor-hook-\(paneID.uuidString).json"
    }

    func start() {
        CursorHookSetup.ensureHooksConfigured()
        startHookFileWatcher()
        fetchVersion()
        refreshNow()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refreshNow()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        hookSource?.cancel()
        hookSource = nil
        try? FileManager.default.removeItem(atPath: hookOutputFilePath)
    }

    var currentDurationMs: Double {
        max(0, Date().timeIntervalSince(processStartTime)) * 1000
    }

    // MARK: - Hook File Watching

    private func startHookFileWatcher() {
        FileManager.default.createFile(atPath: hookOutputFilePath, contents: nil)
        let fd = open(hookOutputFilePath, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        src.setEventHandler { [weak self] in
            self?.handleHookFileUpdate()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        hookSource = src
    }

    private func handleHookFileUpdate() {
        guard let data = try? Data(contentsOf: URL(filePath: hookOutputFilePath)),
            !data.isEmpty
        else { return }

        guard let parsed = CursorHookPayload.parse(data) else { return }

        let model = StatusLineData.Model(id: parsed.model, displayName: parsed.model)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.lastHookModel = model
            self.refreshNow()
        }
    }

    // MARK: - Periodic Refresh

    private func refreshNow() {
        Task { [weak self] in
            guard let self else { return }
            let branch = await self.runShell("git branch --show-current 2>/dev/null")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let wd = self.workingDirectory

            let data = StatusLineData(
                model: self.lastHookModel,
                cost: StatusLineData.Cost(
                    totalCostUsd: nil,
                    totalDurationMs: self.currentDurationMs,
                    totalLinesAdded: nil,
                    totalLinesRemoved: nil
                ),
                contextWindow: nil,
                rateLimits: nil,
                worktree: StatusLineData.Worktree(
                    name: URL(filePath: wd).lastPathComponent,
                    branch: branch
                ),
                workspace: StatusLineData.Workspace(
                    gitWorktree: wd
                ),
                effort: nil,
                thinking: nil,
                agent: nil,
                outputStyle: nil,
                vim: nil,
                sessionName: nil,
                version: self.versionFetchedVersion,
                exceeds200kTokens: nil,
                sessionStatus: nil,
                openCodeMode: nil,
                pr: nil
            )

            await MainActor.run { [weak self] in
                self?.onUpdate?(data)
            }
        }
    }

    private func fetchVersion() {
        Task { [weak self] in
            guard let self else { return }
            let version = await self.runShell(
                "PATH=/opt/homebrew/bin:/usr/local/bin:$PATH agent --version 2>/dev/null | head -1")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run { [weak self] in
                self?.versionFetchedVersion = version
            }
        }
    }

    // MARK: - Shell Helper

    private func runShell(_ command: String) async -> String? {
        await withCheckedContinuation { continuation in
            let task = Process()
            let outPipe = Pipe()
            task.executableURL = URL(filePath: "/bin/zsh")
            task.arguments = ["-c", command]
            task.currentDirectoryURL = URL(filePath: workingDirectory)
            task.standardOutput = outPipe
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { process in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0, !data.isEmpty {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - Hook Payload

/// Minimal representation of the JSON that Cursor pipes to hook scripts via stdin.
/// We only need the `model` field; the rest is ignored via `AdditionalKeysDecodable` pattern.
struct CursorHookPayload {
    let model: String

    static func parse(_ data: Data) -> CursorHookPayload? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let model = dict["model"] as? String,
            !model.isEmpty
        else { return nil }
        return CursorHookPayload(model: model)
    }
}

// MARK: - Hook Setup

/// Manages the user-level `~/.cursor/hooks.json` to include an `afterAgentResponse` hook
/// that writes the hook payload to a per-pane temp file identified by the
/// `AGENT_SESSION_MANAGER_PANE_ID` environment variable.
enum CursorHookSetup {
    private static let hookScriptName = "agent-session-manager-cursor-hook.sh"

    static var hooksDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".cursor/hooks")
    }

    static var hookScriptPath: URL {
        hooksDirectory.appending(path: hookScriptName)
    }

    static var hooksConfigPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".cursor/hooks.json")
    }

    /// The hook script reads stdin (the JSON payload from Cursor) and writes it to a
    /// temp file keyed by the AGENT_SESSION_MANAGER_PANE_ID env var.
    static let hookScriptContent = """
        #!/bin/bash
        if [ -n "$AGENT_SESSION_MANAGER_PANE_ID" ]; then
          cat > "/tmp/agent-session-manager-cursor-hook-${AGENT_SESSION_MANAGER_PANE_ID}.json"
        else
          cat > /dev/null
        fi
        exit 0

        """

    static let hookEntry: [String: Any] = [
        "command": "./hooks/\(hookScriptName)"
    ]

    /// Ensures `~/.cursor/hooks.json` contains our `afterAgentResponse` hook and the
    /// helper script exists. Merges with any existing hooks config non-destructively.
    static func ensureHooksConfigured() {
        do {
            try FileManager.default.createDirectory(at: hooksDirectory, withIntermediateDirectories: true)
            try writeHookScript()
            try mergeHooksConfig()
        } catch {
            // Best-effort; model detection gracefully degrades if hooks aren't set up.
        }
    }

    private static func writeHookScript() throws {
        let scriptPath = hookScriptPath
        let currentContent = try? String(contentsOf: scriptPath, encoding: .utf8)
        if currentContent == hookScriptContent { return }
        try hookScriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
        // chmod +x
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
    }

    private static func mergeHooksConfig() throws {
        let configPath = hooksConfigPath
        var config: [String: Any] = ["version": 1, "hooks": [String: Any]()]

        if let existingData = try? Data(contentsOf: configPath),
            let existing = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]
        {
            config = existing
        }

        var hooks = config["hooks"] as? [String: Any] ?? [:]
        var afterAgentResponseEntries = hooks["afterAgentResponse"] as? [[String: Any]] ?? []

        let alreadyInstalled = afterAgentResponseEntries.contains {
            ($0["command"] as? String)?.contains(hookScriptName) == true
        }

        if !alreadyInstalled {
            afterAgentResponseEntries.append(hookEntry)
            hooks["afterAgentResponse"] = afterAgentResponseEntries
            config["hooks"] = hooks
            if config["version"] == nil { config["version"] = 1 }
            let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: configPath, options: .atomic)
        }
    }
}
