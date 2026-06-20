import AppKit
import XCTest

@testable import AgentSessionManager

@MainActor
final class NotificationSidebarThemeTests: XCTestCase {
    func testNotificationSidebarUsesSidebarBackgroundForAllChromeSurfaces() {
        let expected = NSColor(Theme.sidebarBackground)

        XCTAssertEqual(NSColor(NotificationSidebarTheme.containerBackground), expected)
        XCTAssertEqual(NSColor(NotificationSidebarTheme.headerBackground), expected)
    }
}
