import AppKit
import XCTest

@testable import AgentSessionManager

@MainActor
final class NotificationSidebarThemeTests: XCTestCase {
    func testNotificationSidebarUsesSidebarBackgroundForAllChromeSurfaces() {
        let expected = NSColor(Theme.sidebarBackground)

        XCTAssertEqual(NSColor(NotificationSidebarTheme.containerBackground), expected)
        XCTAssertEqual(NSColor(NotificationSidebarTheme.headerBackground), expected)
        XCTAssertEqual(NSColor(NotificationSidebarTheme.footerBackground), expected)
    }

    func testNotificationSidebarChromeMetricsMatchMainWindowChrome() {
        XCTAssertEqual(NotificationSidebarMetrics.width, 240)
        XCTAssertEqual(MainWindowChromeMetrics.barHeight, 44)
        XCTAssertEqual(NotificationSidebarMetrics.headerHeight, MainWindowChromeMetrics.barHeight)
        XCTAssertEqual(NotificationSidebarMetrics.footerHeight, MainWindowChromeMetrics.barHeight)
    }
}
