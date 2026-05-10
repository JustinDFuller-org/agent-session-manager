import Foundation

final class ToolAgnosticDataProvider {
    let workingDirectory: String
    let toolCommand: String
    let processStartTime: Date
    private var refreshTimer: Timer?
    private var versionFetchedVersion: String?

    var onUpdate: ((StatusLineData) -> Void)?

    init(workingDirectory: String, toolCommand: String, processStartTime: Date) {
        self.workingDirectory = workingDirectory
        self.toolCommand = toolCommand
        self.processStartTime = processStartTime
    }

    func start() {
        fetchVersion()
        refreshNow()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refreshNow()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    var currentDurationMs: Double {
        max(0, Date().timeIntervalSince(processStartTime)) * 1000
    }

    private func refreshNow() {
        Task { [weak self] in
            guard let self else { return }
            let branch = await self.runShell("git branch --show-current 2>/dev/null")?.trimmingCharacters(
                in: .whitespacesAndNewlines)
            let wd = self.workingDirectory

            let data = StatusLineData(
                model: nil,
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
                "PATH=/opt/homebrew/bin:/usr/local/bin:$PATH \(self.toolCommand) --version 2>/dev/null | head -1")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run { [weak self] in
                self?.versionFetchedVersion = version
            }
        }
    }

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
                    let output = String(data: data, encoding: .utf8)
                    continuation.resume(returning: output)
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
