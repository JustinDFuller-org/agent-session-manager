import XCTest

@testable import AgentSessionManager

@MainActor
final class MainBranchUpdateDetectorTests: XCTestCase {
    func testParseCommitSHAIsReachable() {
        let sha = String(repeating: "a", count: 40)
        XCTAssertEqual(MainBranchUpdateDetector.parseCommitSHA(sha), sha)
    }

    func testChannelIsSourceMain() {
        let detector = MainBranchUpdateDetector()
        XCTAssertEqual(detector.channel, .sourceMain)
    }

    func testStopReportsClearedStateToDelegate() {
        let detector = MainBranchUpdateDetector()
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
