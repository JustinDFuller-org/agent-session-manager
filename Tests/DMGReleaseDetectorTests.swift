import Sparkle
import XCTest

@testable import AgentSessionManager

@MainActor
final class DMGReleaseDetectorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TracingService.shared.resetForTesting()
    }

    override func tearDown() {
        TracingService.shared.resetForTesting()
        super.tearDown()
    }

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

    // A Sparkle-driven relaunch must be traceable, not indistinguishable from an unexplained
    // disappearance — see the tracing.md app-lifecycle-correlation section this guards.

    private func makeStandaloneUpdater() -> SPUUpdater {
        SPUUpdater(
            hostBundle: Bundle.main, applicationBundle: Bundle.main,
            userDriver: SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil), delegate: nil)
    }

    func testShouldRelaunchApplicationRecordsSpanAndAllowsRelaunch() {
        TracingService.shared.enableTestCapture()
        let detector = DMGReleaseDetector()

        let shouldRelaunch = detector.updaterShouldRelaunchApplication(makeStandaloneUpdater())

        XCTAssertTrue(shouldRelaunch)
        XCTAssertTrue(
            TracingService.shared.recordedEventsForTesting.contains { $0.name == "update.dmg.should_relaunch" })
    }

    func testWillRelaunchApplicationRecordsSpan() {
        TracingService.shared.enableTestCapture()
        let detector = DMGReleaseDetector()

        detector.updaterWillRelaunchApplication(makeStandaloneUpdater())

        XCTAssertTrue(
            TracingService.shared.recordedEventsForTesting.contains { $0.name == "update.dmg.will_relaunch" })
    }
}

private final class CapturingUpdateDetectorDelegate: UpdateDetectorDelegate {
    private(set) var lastState: UpdateDetectorState?

    func updateDetector(_ detector: UpdateDetector, didUpdateState state: UpdateDetectorState) {
        lastState = state
    }
}
