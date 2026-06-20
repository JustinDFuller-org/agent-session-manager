import AppKit
import XCTest

@testable import AgentSessionManager

@MainActor
final class ThemeTests: XCTestCase {
    func testMainWindowChromeHidesTitleAndUsesFullSizeContentView() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        Theme.configure(window: window, using: Theme.mainWindowChrome)

        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertEqual(window.backgroundColor, NSColor(Theme.mac26WindowChrome))
    }

    func testSettingsWindowChromeDisablesMinimizeAndZoomButtons() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        Theme.configure(window: window, using: Theme.settingsWindowChrome)

        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertFalse(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.standardWindowButton(.closeButton)?.isHidden ?? true)
        XCTAssertFalse(window.standardWindowButton(.miniaturizeButton)?.isEnabled ?? true)
        XCTAssertFalse(window.standardWindowButton(.zoomButton)?.isEnabled ?? true)
    }

    func testDashboardWindowChromeKeepsNativeTitlebarAndButtons() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        Theme.configure(window: window, using: Theme.dashboardWindowChrome)

        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertFalse(window.titlebarAppearsTransparent)
        XCTAssertFalse(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.standardWindowButton(.closeButton)?.isHidden ?? true)
        XCTAssertFalse(window.standardWindowButton(.miniaturizeButton)?.isHidden ?? true)
        XCTAssertFalse(window.standardWindowButton(.zoomButton)?.isHidden ?? true)
    }
}
