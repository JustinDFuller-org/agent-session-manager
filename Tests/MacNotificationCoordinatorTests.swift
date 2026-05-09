import UserNotifications
import XCTest
@testable import AgentSessionManager

final class MacNotificationCoordinatorTests: XCTestCase {

    func testWillPresentIncludesBannerAndSoundWhenAppForeground() {
        let opts = MacNotificationCoordinator.willPresentPresentationOptions
        XCTAssertTrue(opts.contains(.banner))
        XCTAssertTrue(opts.contains(.sound))
    }

    func testDescribeUserNotificationsNSErrorIncludesFailureSiteHintForCode1() {
        let err = NSError(
            domain: UNError.errorDomain,
            code: UNError.Code.notificationsNotAllowed.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Notifications are not allowed for this application."]
        )
        let line = MacNotificationCoordinator.describeUserNotificationsNSError(err)
        XCTAssertTrue(line.contains("unError=notificationsNotAllowed"), line)
        XCTAssertTrue(line.contains("System Settings"), line)
        XCTAssertTrue(line.contains("ad-hoc signed"), line)
    }

    func testDescribeUserNotificationsNSErrorOmitsUnErrorForNonUNDomains() {
        let err = NSError(domain: "TestDomain", code: 99, userInfo: nil)
        let line = MacNotificationCoordinator.describeUserNotificationsNSError(err)
        XCTAssertFalse(line.contains("unError="))
        XCTAssertTrue(line.contains("TestDomain"))
    }
}
