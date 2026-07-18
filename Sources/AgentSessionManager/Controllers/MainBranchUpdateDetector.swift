import Foundation

/// Detects when GitHub `main` has moved ahead of the commit this source build was made from.
/// Only active for `make`-built binaries on the `main` branch (see `DistributionChannel`).
@MainActor
final class MainBranchUpdateDetector: UpdateDetector {
    static let githubRepoSlug = "JustinDFuller/agent-session-manager"

    let channel: DistributionChannel = .sourceMain

    weak var delegate: UpdateDetectorDelegate?

    private(set) var updateAvailable = false
    private(set) var latestVersion: String?
    private(set) var lastCheckedAt: Date?
    private(set) var isChecking = false

    private var builtCommit: String?
    private var builtCommitDate: Date?
    private var timer: Timer?
    private var activeProcess: Process?
    private var timeoutWorkItem: DispatchWorkItem?

    init() {}

    func start() {
        guard let provenance = BuildProvenance.current() else { return }
        builtCommit = provenance.commit
        builtCommitDate = provenance.commitDate

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.check() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        activeProcess?.terminate()
        activeProcess = nil
        isChecking = false
        updateAvailable = false
        latestVersion = nil
        reportState()
    }

    // Source-main builds require manual `git pull && make run`; no in-app install path.
    func performUpdate() {}

    func check() {
        guard let builtCommit else { return }
        guard SettingsPersistence.isUpdateReminderEnabled() else { return }

        timeoutWorkItem?.cancel()
        activeProcess?.terminate()
        activeProcess = nil

        let task = Process()
        let outPipe = Pipe()
        task.executableURL = URL(filePath: "/bin/zsh")
        task.arguments = ["-c", "gh api repos/\(Self.githubRepoSlug)/commits/main --jq .sha"]
        task.standardOutput = outPipe
        task.standardError = FileHandle.nullDevice

        let startTime = Date()
        let timeoutWork = DispatchWorkItem { [weak task] in task?.terminate() }
        timeoutWorkItem = timeoutWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeoutWork)

        task.terminationHandler = { [weak self] _ in
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: outData, encoding: .utf8) ?? ""
            let latest = Self.parseCommitSHA(text)
            Task { @MainActor [weak self] in
                self?.handleCheckResult(latest: latest, builtCommit: builtCommit, startTime: startTime)
            }
        }

        isChecking = true
        activeProcess = task
        reportState()
        do {
            try task.run()
        } catch {
            isChecking = false
            activeProcess = nil
            timeoutWork.cancel()
            reportState()
        }
    }

    private func handleCheckResult(latest: String?, builtCommit: String, startTime: Date) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        activeProcess = nil
        isChecking = false
        lastCheckedAt = Date()

        guard let latest else {
            TracingService.shared.record(
                "update.check.ran",
                startTime: startTime,
                endTime: Date(),
                attributes: ["result": "error"])
            reportState()
            return
        }

        latestVersion = latest
        updateAvailable = Self.isUpdateAvailable(builtCommit: builtCommit, latestCommit: latest)
        TracingService.shared.record(
            "update.check.ran",
            startTime: startTime,
            endTime: Date(),
            attributes: [
                "result": "ok",
                "update_available": String(updateAvailable),
            ])
        reportState()
    }

    private func reportState() {
        delegate?.updateDetector(
            self,
            didUpdateState: UpdateDetectorState(
                updateAvailable: updateAvailable,
                latestVersion: latestVersion,
                lastCheckedAt: lastCheckedAt,
                isChecking: isChecking
            ))
    }

    // MARK: - Pure helpers (internal for testing)

    /// Parses `gh api .../commits/main --jq .sha` output (a bare 40-char SHA, possibly with a
    /// trailing newline); returns `nil` for empty/malformed output.
    nonisolated static func parseCommitSHA(_ output: String) -> String? {
        let sha = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sha.count == 40, sha.allSatisfy(\.isHexDigit) else { return nil }
        return sha
    }

    nonisolated static func isUpdateAvailable(builtCommit: String, latestCommit: String) -> Bool {
        builtCommit != latestCommit
    }
}
