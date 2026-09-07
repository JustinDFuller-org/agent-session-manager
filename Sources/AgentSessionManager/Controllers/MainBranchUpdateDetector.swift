import Foundation

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
    private var activeTask: Task<Void, Never>?

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
        activeTask?.cancel()
        activeTask = nil
        isChecking = false
        updateAvailable = false
        latestVersion = nil
        reportState()
    }

    func performUpdate() {}

    func check() {
        guard let builtCommit else { return }
        guard SettingsPersistence.isUpdateReminderEnabled() else { return }

        let startTime = Date()
        isChecking = true
        reportState()
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            let result = await GitHubCLIRunner.shared.run(
                arguments: ["api", "repos/\(Self.githubRepoSlug)/commits/main", "--jq", ".sha"],
                timeout: 15)
            guard let self else { return }
            let latest =
                result.succeeded ? Self.parseCommitSHA(String(data: result.stdout, encoding: .utf8) ?? "") : nil
            self.handleCheckResult(
                latest: latest, failure: result.failure, builtCommit: builtCommit, startTime: startTime)
        }
    }

    private func handleCheckResult(latest: String?, failure: GitHubCLIFailure?, builtCommit: String, startTime: Date) {
        activeTask = nil
        isChecking = false
        lastCheckedAt = Date()

        guard let latest else {
            TracingService.shared.record(
                "update.check.ran",
                startTime: startTime,
                endTime: Date(),
                attributes: ["result": failure?.rawValue ?? GitHubCLIFailure.parse.rawValue])
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

    nonisolated static func parseCommitSHA(_ output: String) -> String? {
        let sha = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sha.count == 40, sha.allSatisfy(\.isHexDigit) else { return nil }
        return sha
    }

    nonisolated static func isUpdateAvailable(builtCommit: String, latestCommit: String) -> Bool {
        builtCommit != latestCommit
    }
}
