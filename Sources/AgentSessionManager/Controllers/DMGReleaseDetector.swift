import Foundation
import Sparkle

/// Detects newer DMG releases by polling the Sparkle appcast. Only active for DMG builds
/// marked with `ASMDistributionChannel == "dmg"` and a valid `SUFeedURL` + `SUPublicEdKey`.
@MainActor
final class DMGReleaseDetector: NSObject, UpdateDetector {
    let channel: DistributionChannel = .dmg

    weak var delegate: UpdateDetectorDelegate?

    private(set) var updateAvailable = false
    private(set) var latestVersion: String?
    private(set) var lastCheckedAt: Date?
    private(set) var isChecking = false

    private var updater: SPUUpdater?
    private var userDriver: SPUUserDriver?

    override init() {}

    func start() {
        guard Bundle.main.infoDictionary?["SUFeedURL"] is String,
            Bundle.main.infoDictionary?["SUPublicEdKey"] is String
        else {
            return
        }

        let userDriver = SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil)
        self.userDriver = userDriver

        let updater = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: userDriver,
            delegate: self
        )
        self.updater = updater
        updater.automaticallyChecksForUpdates = false

        do {
            try updater.start()
        } catch {
            // Sparkle is unavailable for this configuration; remain dormant.
        }
    }

    func stop() {
        updater = nil
        userDriver = nil
        updateAvailable = false
        latestVersion = nil
        isChecking = false
        reportState()
    }

    func check() {
        isChecking = true
        reportState()
        updater?.checkForUpdatesInBackground()
    }

    func performUpdate() {
        isChecking = true
        reportState()
        updater?.checkForUpdates()
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
}

extension DMGReleaseDetector: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateAvailable = true
        latestVersion = item.displayVersionString
        isChecking = false
        lastCheckedAt = Date()
        reportState()
        TracingService.shared.record(
            "update.check.dmg.ran",
            attributes: [
                "result": "ok",
                "update_available": "true",
                "latest_version": item.displayVersionString,
            ])
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        updateAvailable = false
        latestVersion = nil
        isChecking = false
        lastCheckedAt = Date()
        reportState()
        TracingService.shared.record(
            "update.check.dmg.ran",
            attributes: [
                "result": "ok",
                "update_available": "false",
            ])
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        isChecking = false
        reportState()
        TracingService.shared.record(
            "update.check.dmg.ran",
            attributes: [
                "result": "error",
                "error": String(describing: error),
            ])
    }
}
