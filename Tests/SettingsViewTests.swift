import XCTest

@testable import AgentSessionManager

final class SettingsViewTests: XCTestCase {
    func testSidebarMetricsKeepBorderAndRowsAligned() {
        XCTAssertEqual(SettingsSidebarMetrics.contentWidth + (SettingsSidebarMetrics.outerPadding * 2), 224)
        XCTAssertEqual(SettingsSidebarMetrics.rowHeight, 44)
        XCTAssertEqual(SettingsSidebarMetrics.rowSpacing, 4)
        XCTAssertEqual(SettingsSidebarMetrics.rowCornerRadius, 8)
        XCTAssertGreaterThan(SettingsSidebarMetrics.rowHorizontalPadding, 0)
    }
}
