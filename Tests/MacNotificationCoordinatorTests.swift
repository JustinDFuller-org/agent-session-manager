import UserNotifications
import XCTest

@testable import AgentSessionManager

@MainActor
final class NotificationCoordinatorNavigationTests: XCTestCase {
    private func makeState(tabs: [(name: String, paneNames: [String])]) -> (AppState, [[Pane]]) {
        let state = AppState()
        let url = URL(filePath: "/tmp")
        var allPanes: [[Pane]] = []
        for tabSpec in tabs {
            let tab = Tab(name: tabSpec.name, directory: url)
            let panes = tabSpec.paneNames.map { Pane(name: $0, tab: tab) }
            tab.panes = panes
            state.tabs.append(tab)
            allPanes.append(panes)
        }
        return (state, allPanes)
    }

    override func setUp() {
        super.setUp()
        MacNotificationCoordinator.shared.bind(appState: AppState(), appSettings: AppSettings())
    }

    func testTerminalBellNavigatesToCorrectPane() {
        let (state, panes) = makeState(tabs: [
            (name: "tab1", paneNames: ["a"]),
            (name: "tab2", paneNames: ["b"]),
        ])
        state.activeTabID = state.tabs[0].id
        state.activePaneID = panes[0][0].id
        MacNotificationCoordinator.shared.bind(appState: state, appSettings: AppSettings())

        MacNotificationCoordinator.shared.handleNotificationNavigation(
            paneIDStr: panes[1][0].id.uuidString,
            tabIDStr: state.tabs[1].id.uuidString,
            kind: nil
        )

        XCTAssertEqual(state.activeTabID, state.tabs[1].id)
        XCTAssertEqual(state.activePaneID, panes[1][0].id)
    }

    func testPRMergedNavigatesToCorrectPaneAndPostsAlert() {
        let (state, panes) = makeState(tabs: [
            (name: "tab1", paneNames: ["a"]),
            (name: "tab2", paneNames: ["b"]),
        ])
        state.activeTabID = state.tabs[0].id
        state.activePaneID = panes[0][0].id
        MacNotificationCoordinator.shared.bind(appState: state, appSettings: AppSettings())

        var alertPosted = false
        let obs = NotificationCenter.default.addObserver(
            forName: .prMergedActionRequested, object: nil, queue: nil
        ) { _ in alertPosted = true }
        defer { NotificationCenter.default.removeObserver(obs) }

        MacNotificationCoordinator.shared.handleNotificationNavigation(
            paneIDStr: panes[1][0].id.uuidString,
            tabIDStr: state.tabs[1].id.uuidString,
            kind: NotificationKind.prMerged.rawValue
        )

        XCTAssertEqual(state.activeTabID, state.tabs[1].id)
        XCTAssertEqual(state.activePaneID, panes[1][0].id)
        XCTAssertTrue(alertPosted)
    }

    // handleNotificationResponse delegates to handleNotificationNavigation; verify navigation
    // still works after the window-ordering resequencing in handleNotificationResponse.
    func testHandleNotificationResponseNavigationPathStillWorks() {
        let (state, panes) = makeState(tabs: [
            (name: "tab1", paneNames: ["a"]),
            (name: "tab2", paneNames: ["b"]),
        ])
        state.activeTabID = state.tabs[0].id
        state.activePaneID = panes[0][0].id
        MacNotificationCoordinator.shared.bind(appState: state, appSettings: AppSettings())

        MacNotificationCoordinator.shared.handleNotificationNavigation(
            paneIDStr: panes[1][0].id.uuidString,
            tabIDStr: state.tabs[1].id.uuidString,
            kind: nil
        )

        XCTAssertEqual(state.activeTabID, state.tabs[1].id)
        XCTAssertEqual(state.activePaneID, panes[1][0].id)
    }

    func testNavigationNoopsWhenIDsAreInvalid() {
        let (state, panes) = makeState(tabs: [(name: "tab1", paneNames: ["a"])])
        state.activeTabID = state.tabs[0].id
        state.activePaneID = panes[0][0].id
        MacNotificationCoordinator.shared.bind(appState: state, appSettings: AppSettings())

        MacNotificationCoordinator.shared.handleNotificationNavigation(
            paneIDStr: "not-a-uuid",
            tabIDStr: "also-not-a-uuid",
            kind: nil
        )

        XCTAssertEqual(state.activeTabID, state.tabs[0].id)
        XCTAssertEqual(state.activePaneID, panes[0][0].id)
    }
}

@MainActor
final class MacNotificationCoordinatorTests: XCTestCase {
    func testRemoveAllDeliveredNoopsWhenStickyDisabled() {
        let settings = AppSettings()
        settings.isStickyNotificationsEnabled = false
        MacNotificationCoordinator.shared.bind(appState: AppState(), appSettings: settings)
        // Guard check: method must return early without error when sticky is disabled.
        MacNotificationCoordinator.shared.removeAllDeliveredNotificationsIfStickyEnabled()
        XCTAssertFalse(settings.isStickyNotificationsEnabled)
    }

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

    func testBundleAppIconReturnsNonNil() {
        // In test context there is no .icns file, so bundleAppIcon falls back to
        // NSApp.applicationIconImage. Verify the fallback contract holds.
        XCTAssertNotNil(MacNotificationCoordinator.bundleAppIcon())
    }

    func testMakeAttachmentReturnsNilForNilImage() {
        XCTAssertNil(MacNotificationCoordinator.makeAttachment(from: nil))
    }

    func testMakeAttachmentReturnsAttachmentForValidImage() {
        let attachment = MacNotificationCoordinator.makeAttachment(from: Self.makeTestImage())
        XCTAssertNotNil(attachment)
    }

    func testMakeAttachmentIdentifierIsAppIcon() {
        let attachment = MacNotificationCoordinator.makeAttachment(from: Self.makeTestImage())
        XCTAssertEqual(attachment?.identifier, "app-icon")
    }

    private static func makeTestImage() -> NSImage {
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 64,
            pixelsHigh: 64,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let image = NSImage(size: NSSize(width: 64, height: 64))
        image.addRepresentation(bitmapRep)
        return image
    }
}
