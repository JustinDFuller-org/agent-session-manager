import AppKit
import XCTest

@testable import AgentSessionManager

@MainActor
final class MainWindowControllerTests: XCTestCase {
    private func makeWindow(title: String, styleMask: NSWindow.StyleMask = [.titled, .closable]) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = title
        return window
    }

    func testMainWindowTitlesIncludeProductionAndDev() {
        XCTAssertTrue(MainWindowController.mainWindowTitles.contains(MainWindowController.productionTitle))
        XCTAssertTrue(MainWindowController.mainWindowTitles.contains(MainWindowController.devTitle))
        XCTAssertEqual(MainWindowController.mainWindowTitles.count, 2)
    }

    func testIsMainAppWindowAcceptsProductionTitle() {
        let window = makeWindow(title: MainWindowController.productionTitle)
        XCTAssertTrue(MainWindowController.isMainAppWindow(window))
    }

    func testIsMainAppWindowAcceptsDevTitle() {
        let window = makeWindow(title: MainWindowController.devTitle)
        XCTAssertTrue(MainWindowController.isMainAppWindow(window))
    }

    func testIsMainAppWindowRejectsSettingsTitle() {
        let window = makeWindow(title: "Settings")
        XCTAssertFalse(MainWindowController.isMainAppWindow(window))
    }

    func testIsMainAppWindowRejectsEmptyTitle() {
        let window = makeWindow(title: "")
        XCTAssertFalse(MainWindowController.isMainAppWindow(window))
    }

    func testIsMainAppWindowRejectsPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.nonactivatingPanel, .titled],
            backing: .buffered,
            defer: false
        )
        panel.title = MainWindowController.productionTitle
        XCTAssertFalse(MainWindowController.isMainAppWindow(panel))
    }

    func testPreferredMainWindowReturnsSingleMainWindow() {
        let window = makeWindow(title: MainWindowController.productionTitle)
        window.orderFrontRegardless()
        defer { window.close() }
        XCTAssertEqual(MainWindowController.preferredMainWindow(), window)
    }
}
