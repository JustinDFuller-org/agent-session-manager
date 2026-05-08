import UserNotifications
import XCTest
@testable import AgentSessionManager

final class MacNotificationCoordinatorTests: XCTestCase {

    func testWillPresentIncludesBannerAndSoundWhenAppForeground() {
        let opts = MacNotificationCoordinator.willPresentPresentationOptions
        XCTAssertTrue(opts.contains(.banner))
        XCTAssertTrue(opts.contains(.sound))
    }
}
