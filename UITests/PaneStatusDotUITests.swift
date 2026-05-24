import XCTest

final class PaneStatusDotUITests: XCTestCase {
    var app: XCUIApplication!

    private static let tabID = "44444444-4444-4444-4444-444444444444"
    private static let paneID = "55555555-5555-5555-5555-555555555555"

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

    func testStatusDotExistsForRunningPane() {
        injectSession(isMerged: false)
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()

        let dot = app.otherElements["pane-status-dot-test-pane"]
        XCTAssertTrue(dot.waitForExistence(timeout: 5), "Expected status dot for 'test-pane'")
    }

    func testStatusDotMergedIdentifierSetWhenIsMerged() {
        injectSession(isMerged: true)
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()

        let mergedDot = app.otherElements["pane-status-dot-merged-test-pane"]
        XCTAssertTrue(
            mergedDot.waitForExistence(timeout: 5),
            "Expected merged status dot identifier for pane with isMerged: true"
        )
    }

    private func injectSession(isMerged: Bool) {
        let workspaceDir = GitUITestWorkspace.directoryURL.path
        let json = """
            {
              "tabs": [
                {
                  "id": "\(Self.tabID)",
                  "name": "TestTab",
                  "directory": "\(workspaceDir)",
                  "panes": [
                    {
                      "id": "\(Self.paneID)",
                      "name": "test-pane",
                      "cliType": "claude",
                      "isPriority": false,
                      "isMerged": \(isMerged),
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
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? json.data(using: .utf8)?.write(to: sessionURL)
    }
}
