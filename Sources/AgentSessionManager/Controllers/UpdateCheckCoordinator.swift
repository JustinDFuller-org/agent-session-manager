import AppKit
import Foundation
import Observation

/// Routes update detection to the detector appropriate for the current `DistributionChannel`.
/// `sourceMain` builds use `MainBranchUpdateDetector`; released DMG builds use
/// `DMGReleaseDetector` (Sparkle). All other builds remain dormant.
@Observable
@MainActor
final class UpdateCheckCoordinator: UpdateDetectorDelegate {
    static let shared = UpdateCheckCoordinator()

    private(set) var updateAvailable = false
    private(set) var latestVersion: String?
    private(set) var lastCheckedAt: Date?
    private(set) var isChecking = false
    private(set) var channel: DistributionChannel? = nil

    private var activeDetector: UpdateDetector?
    private var activeObserver: Any?
    private var lastActiveCheck: Date?

    private init() {}

    /// Call once at startup. No-op unless this build is a `sourceMain` or `dmg` distribution
    /// and the user hasn't disabled the reminder in Settings.
    func start() {
        let currentChannel = DistributionChannel.current()
        guard currentChannel == .sourceMain || currentChannel == .dmg else {
            channel = currentChannel
            return
        }
        channel = currentChannel

        activeDetector?.stop()
        let detector: UpdateDetector
        switch currentChannel {
        case .sourceMain:
            detector = MainBranchUpdateDetector()
        case .dmg:
            detector = DMGReleaseDetector()
        default:
            return
        }
        detector.delegate = self
        activeDetector = detector
        detector.start()

        check()

        if activeObserver == nil {
            activeObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.checkOnActivateIfDue() }
            }
        }
    }

    /// Called when the user disables the reminder in Settings. Clears state so the tab-bar
    /// pill disappears immediately, and stops the active detector.
    func stop() {
        activeDetector?.stop()
        activeDetector = nil
        updateAvailable = false
        latestVersion = nil
        lastCheckedAt = nil
        isChecking = false
        channel = nil
    }

    /// Triggers a manual or periodic check on the active detector.
    func check() {
        activeDetector?.check()
    }

    /// Triggers the platform-appropriate update UI (Sparkle for DMG, Settings for source builds).
    func performUpdate() {
        activeDetector?.performUpdate()
    }

    private func checkOnActivateIfDue() {
        let now = Date()
        if let last = lastActiveCheck, now.timeIntervalSince(last) < 3600 { return }
        lastActiveCheck = now
        check()
    }

    func updateDetector(_ detector: UpdateDetector, didUpdateState state: UpdateDetectorState) {
        updateAvailable = state.updateAvailable
        latestVersion = state.latestVersion
        lastCheckedAt = state.lastCheckedAt
        isChecking = state.isChecking
    }
}
