import XCTest

@testable import AgentSessionManager

@MainActor
final class DMGReleaseDetectorTests: XCTestCase {
    func testChannelIsDMG() {
        let detector = DMGReleaseDetector()
        XCTAssertEqual(detector.channel, .dmg)
    }

    func testStartWithoutSparkleKeysDoesNotCrash() {
        let detector = DMGReleaseDetector()
        detector.start()
        XCTAssertFalse(detector.updateAvailable)
        XCTAssertFalse(detector.isChecking)
    }

    func testStopReportsClearedStateToDelegate() {
        let detector = DMGReleaseDetector()
        let delegate = CapturingUpdateDetectorDelegate()
        detector.delegate = delegate
        detector.stop()
        XCTAssertNotNil(delegate.lastState)
        XCTAssertFalse(delegate.lastState?.updateAvailable ?? true)
        XCTAssertFalse(delegate.lastState?.isChecking ?? true)
    }
}

private final class CapturingUpdateDetectorDelegate: UpdateDetectorDelegate {
    private(set) var lastState: UpdateDetectorState?

    func updateDetector(_ detector: UpdateDetector, didUpdateState state: UpdateDetectorState) {
        lastState = state
    }
}
