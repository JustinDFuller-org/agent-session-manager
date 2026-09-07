import Foundation

struct UpdateDetectorState: Equatable {
    var updateAvailable: Bool = false
    var latestVersion: String?
    var lastCheckedAt: Date?
    var isChecking: Bool = false
}

@MainActor
protocol UpdateDetectorDelegate: AnyObject {
    func updateDetector(_ detector: UpdateDetector, didUpdateState state: UpdateDetectorState)
}

@MainActor
protocol UpdateDetector: AnyObject {
    var channel: DistributionChannel { get }
    var delegate: UpdateDetectorDelegate? { get set }

    func start()
    func stop()
    func check()
    func performUpdate()
}
