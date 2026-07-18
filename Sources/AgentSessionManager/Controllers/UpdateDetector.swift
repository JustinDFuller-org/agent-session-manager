import Foundation

/// Observable state reported by an `UpdateDetector` to its delegate.
struct UpdateDetectorState: Equatable {
    var updateAvailable: Bool = false
    var latestVersion: String? = nil
    var lastCheckedAt: Date? = nil
    var isChecking: Bool = false
}

/// Receives state changes from an active `UpdateDetector` implementation.
@MainActor
protocol UpdateDetectorDelegate: AnyObject {
    func updateDetector(_ detector: UpdateDetector, didUpdateState state: UpdateDetectorState)
}

/// Abstraction over the different ways Agent Session Manager can detect that a newer
/// build is available. The active detector is selected from `DistributionChannel`.
@MainActor
protocol UpdateDetector: AnyObject {
    var channel: DistributionChannel { get }
    var delegate: UpdateDetectorDelegate? { get set }

    func start()
    func stop()
    func check()
    func performUpdate()
}
