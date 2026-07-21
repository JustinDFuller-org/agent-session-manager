import AppKit
import XCTest

@testable import AgentSessionManager

@MainActor
final class SettingsViewTests: XCTestCase {
    func testSidebarMetricsKeepBorderAndRowsAligned() {
        XCTAssertEqual(SettingsSidebarMetrics.contentWidth + (SettingsSidebarMetrics.outerPadding * 2), 224)
        XCTAssertEqual(SettingsSidebarMetrics.rowHeight, 44)
        XCTAssertEqual(SettingsSidebarMetrics.rowSpacing, 4)
        XCTAssertEqual(SettingsSidebarMetrics.rowCornerRadius, 8)
        XCTAssertGreaterThan(SettingsSidebarMetrics.rowHorizontalPadding, 0)
    }

    func testSettingsSectionSidebarMetadataMatchesExpectedOrder() {
        let expectedOrder: [SettingsSection] = [
            .panes,
            .profiles,
            .tools,
            .shortcuts,
            .statusLine,
            .notifications,
            .debug,
            .about,
        ]
        let expectedTitles = [
            "Panes",
            "Profiles",
            "Harnesses",
            "Shortcuts",
            "Status Line",
            "Notifications",
            "Debug",
            "About",
        ]
        let expectedIcons = [
            "square.split.2x1",
            "person.crop.rectangle.stack",
            "wrench.and.screwdriver",
            "keyboard",
            "chart.bar",
            "bell",
            "ladybug",
            "info.circle",
        ]

        XCTAssertEqual(SettingsSection.allCases, expectedOrder)
        XCTAssertEqual(SettingsSection.allCases.map(\.title), expectedTitles)
        XCTAssertEqual(SettingsSection.allCases.map(\.icon), expectedIcons)
    }

    func testSettingsSidebarThemeKeepsLightGutterAndDarkInsetPanel() {
        XCTAssertEqual(NSColor(SettingsSidebarTheme.gutterBackground), NSColor(Theme.mac26Content))
        XCTAssertEqual(NSColor(SettingsSidebarTheme.panelBackground), NSColor(Theme.mac26WindowChrome))
    }
}
