import AppKit
import Foundation
import Observation

/// Detects when GitHub `main` has moved ahead of the commit this build was made from.
/// Only active for `make`-built binaries on the `main` branch (see `BuildProvenance`) —
/// any other build (Xcode, `swift build`, a future DMG/Homebrew install) has no provenance
/// keys and `start()` is a no-op, leaving the feature dormant.
@Observable
@MainActor
final class UpdateCheckCoordinator {
    static let shared = UpdateCheckCoordinator()

    /// `gh api` requires auth even for read access, since the repo is private — see `check()`.
    static let githubRepoSlug = "JustinDFuller/agent-session-manager"
    private static let checkInterval: TimeInterval = 6 * 3600
    private static let activeCheckThrottle: TimeInterval = 3600

    private(set) var updateAvailable = false
    private(set) var builtCommit: String?
    private(set) var builtCommitDate: Date?
    private(set) var latestCommit: String?
    private(set) var lastCheckedAt: Date?
    private(set) var isChecking = false

    private var timer: Timer?
    private var activeProcess: Process?
    private var timeoutWorkItem: DispatchWorkItem?
    private var lastActiveCheck: Date?
    @ObservationIgnored nonisolated(unsafe) private var activeObserver: Any?

    private init() {}

    /// Call once at startup. No-op unless this build was made from `main` via `make` and the
    /// user hasn't disabled the reminder in Settings.
    func start() {
        guard let provenance = BuildProvenance.current(), provenance.isMainSourceBuild else { return }
        guard SettingsPersistence.isUpdateReminderEnabled() else { return }

        builtCommit = provenance.commit
        builtCommitDate = provenance.commitDate

        check()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.check() }
        }

        if activeObserver == nil {
            activeObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.checkOnActivateIfDue() }
            }
        }
    }

    /// Called when the user disables the reminder in Settings. Clears state so the tab-bar
    /// pill disappears immediately, and stops the periodic timer.
    func stop() {
        timer?.invalidate()
        timer = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        activeProcess?.terminate()
        activeProcess = nil
        isChecking = false
        updateAvailable = false
    }

    private func checkOnActivateIfDue() {
        let now = Date()
        if let last = lastActiveCheck, now.timeIntervalSince(last) < Self.activeCheckThrottle { return }
        lastActiveCheck = now
        check()
    }

    /// Runs `gh api` for the current `main` tip commit. The repo is private, so this needs the
    /// user's already-authenticated `gh` session (same pattern as `PRTrackingCoordinator`) — a
    /// plain unauthenticated `git ls-remote` over HTTPS 404s. Best-effort: a failure (no `gh`,
    /// not logged in, offline) just leaves the prior state in place.
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
        do {
            try task.run()
        } catch {
            isChecking = false
            activeProcess = nil
            timeoutWork.cancel()
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
            return
        }

        latestCommit = latest
        updateAvailable = Self.isUpdateAvailable(builtCommit: builtCommit, latestCommit: latest)
        TracingService.shared.record(
            "update.check.ran",
            startTime: startTime,
            endTime: Date(),
            attributes: [
                "result": "ok",
                "update_available": String(updateAvailable),
            ])
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
