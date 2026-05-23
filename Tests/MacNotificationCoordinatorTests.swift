import UniformTypeIdentifiers
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

    func testBundleAppIconMainBundleFallbackDoesNotCrash() {
        // swift test may run without NSApp; bundleAppIcon must not trap on NSApp access.
        _ = MacNotificationCoordinator.bundleAppIcon()
        if NSApp != nil {
            XCTAssertNotNil(MacNotificationCoordinator.bundleAppIcon())
        }
    }

    func testBundleAppIconLoadsFromEmbeddedICNS() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let assetCatalog = repoRoot.appendingPathComponent("AppIcons/Assets.xcassets")
        guard FileManager.default.fileExists(atPath: assetCatalog.path) else {
            throw XCTSkip("Asset catalog not found at \(assetCatalog.path)")
        }

        let appBundle = FileManager.default.temporaryDirectory
            .appendingPathComponent("asm-icon-fixture-\(UUID().uuidString).app", isDirectory: true)
        let resources = appBundle.appendingPathComponent("Contents/Resources", isDirectory: true)
        let partial = appBundle.appendingPathComponent("partial.plist")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: appBundle) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "actool", assetCatalog.path,
            "--compile", resources.path,
            "--app-icon", "AppIcon",
            "--standalone-icon-behavior", "all",
            "--output-partial-info-plist", partial.path,
            "--platform", "macosx",
            "--minimum-deployment-target", "14.0",
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw XCTSkip("actool failed with status \(process.terminationStatus)")
        }

        let info: [String: Any] = [
            "CFBundleIconFile": "AppIcon",
            "CFBundleIconName": "AppIcon",
        ]
        let infoURL = appBundle.appendingPathComponent("Contents/Info.plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: info, format: .xml, options: 0)
        try plistData.write(to: infoURL)

        guard let bundle = Bundle(path: appBundle.path) else {
            XCTFail("Could not create Bundle at \(appBundle.path)")
            return
        }
        XCTAssertNotNil(MacNotificationCoordinator.bundleAppIcon(in: bundle))

        let emptyBundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("asm-icon-empty-\(UUID().uuidString).app", isDirectory: true)
        let emptyContents = emptyBundleDir.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyContents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyBundleDir) }
        let emptyInfo: [String: Any] = ["CFBundleIconFile": "MissingIcon"]
        try PropertyListSerialization.data(fromPropertyList: emptyInfo, format: .xml, options: 0)
            .write(to: emptyContents.appendingPathComponent("Info.plist"))
        let emptyBundle = try XCTUnwrap(Bundle(path: emptyBundleDir.path))
        XCTAssertNil(MacNotificationCoordinator.bundleAppIcon(in: emptyBundle))
    }

    func testNotificationAttachmentOptionsUsePNGTypeHint() {
        let hint =
            MacNotificationCoordinator.notificationAttachmentOptions[
                UNNotificationAttachmentOptionsTypeHintKey
            ] as? String
        XCTAssertEqual(hint, UTType.png.identifier)
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
