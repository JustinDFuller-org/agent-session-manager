import XCTest

final class PaneLoadingTests: XCTestCase {
    var app: XCUIApplication!

    private static let tabID = "a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1"
    private static let loadingPaneID = "b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2"
    private static let errorPaneID = "c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3"

    private var sessionURL: URL {
        UITestAppSupport.directory.appending(path: "sessions.json")
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        GitUITestWorkspace.prepareCleanRepo()
    }

    override func tearDown() {
        app?.terminate()
        try? FileManager.default.removeItem(at: sessionURL)
        super.tearDown()
    }

    func testLoadingOverlayIsVisible() {
        let workspaceDir = GitUITestWorkspace.directoryURL.path
        let json = makeSessionJSON(
            tabID: Self.tabID,
            tabName: "LoadingTab",
            paneID: Self.loadingPaneID,
            paneName: "loading-pane",
            workspaceDir: workspaceDir
        )
        writeSession(json)

        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--inject-pane-loading=\(Self.loadingPaneID)",
        ]
        app.launch()
        app.activate()

        let overlay = app.descendants(matching: .any)
            .matching(identifier: "pane-loading-overlay-loading-pane").firstMatch
        XCTAssertTrue(overlay.waitForExistence(timeout: 15))
    }

    func testErrorOverlayIsVisible() {
        let workspaceDir = GitUITestWorkspace.directoryURL.path
        let json = makeSessionJSON(
            tabID: Self.tabID,
            tabName: "ErrorTab",
            paneID: Self.errorPaneID,
            paneName: "error-pane",
            workspaceDir: workspaceDir
        )
        writeSession(json)

        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--inject-pane-error=\(Self.errorPaneID)",
        ]
        app.launch()
        app.activate()

        let overlay = app.descendants(matching: .any)
            .matching(identifier: "pane-error-overlay-error-pane").firstMatch
        XCTAssertTrue(overlay.waitForExistence(timeout: 15))
    }

    private func makeSessionJSON(
        tabID: String, tabName: String, paneID: String, paneName: String, workspaceDir: String
    ) -> String {
        """
        {
          "tabs": [
            {
              "id": "\(tabID)",
              "name": "\(tabName)",
              "directory": "\(workspaceDir)",
              "panes": [
                {
                  "id": "\(paneID)",
                  "name": "\(paneName)",
                  "harness": "claude",
                  "isPriority": false,
                  "isMerged": false,
                  "worktreeDirectory": "\(workspaceDir)",
                  "worktreeIsManaged": false
                }
              ]
            }
          ],
          "activeTabIndex": 0,
          "pendingNotifications": []
        }
        """
    }

    private func writeSession(_ json: String) {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? json.data(using: .utf8)?.write(to: sessionURL)
    }
}
