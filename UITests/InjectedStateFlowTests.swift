import XCTest

/// Tests that require pre-injected session state. Does not extend BaseTestCase because
/// each test function controls its own launch arguments and injected JSON.
final class InjectedStateFlowTests: XCTestCase {
    var app: XCUIApplication!

    private static let tabID = "11111111-1111-1111-1111-111111111111"
    private static let paneID = "22222222-2222-2222-2222-222222222222"
    private static let notifID = "33333333-3333-3333-3333-333333333333"

    private static let statusTabID = "44444444-4444-4444-4444-444444444444"
    private static let statusPaneID = "55555555-5555-5555-5555-555555555555"

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

    func testPaneStatusDotFlow() {
        injectStatusSession()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()

        // Running pane: status dot present with standard identifier
        // Circle shapes don't appear under otherElements — search all descendants.
        let runningDot = app.descendants(matching: .any).matching(identifier: "pane-status-dot-running-pane").firstMatch
        XCTAssertTrue(runningDot.waitForExistence(timeout: 15))

        // Merged pane: status dot uses merged-prefixed identifier
        let mergedDot = app.descendants(matching: .any).matching(identifier: "pane-status-dot-merged-merged-pane").firstMatch
        XCTAssertTrue(mergedDot.waitForExistence(timeout: 15))
    }

    func testPRMergedNotificationFlow() {
        injectPRMergedSession()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()

        // Sidebar shows notification row with PR number.
        // Plain-style buttons don't always appear under app.buttons — search all descendants.
        let row = app.descendants(matching: .any).matching(identifier: "notification-row-test-pane").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))

        // Clicking row shows action alert with all three buttons
        row.click()
        let alertTitle = app.staticTexts["PR Merged"]
        XCTAssertTrue(alertTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close Pane"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close Pane and Clean Up Worktree"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3))

        // Cancel dismisses the alert — scope to main window to avoid Touch Bar element
        let cancelButton = app.windows.firstMatch.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.click()
        let alertPred = NSPredicate(format: "exists == false")
        let alertExp = XCTNSPredicateExpectation(predicate: alertPred, object: alertTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [alertExp], timeout: 3), .completed)

        // Tab is active after dismissing alert
        let tabButton = app.buttons.matching(identifier: "tab-button-TestTab").firstMatch
        XCTAssertTrue(tabButton.waitForExistence(timeout: 3))
        XCTAssertEqual(tabButton.value as? String, "active")

        // Status dot stays purple after notification is dismissed
        let mergedDot = app.descendants(matching: .any).matching(identifier: "pane-status-dot-merged-test-pane").firstMatch
        XCTAssertTrue(mergedDot.waitForExistence(timeout: 3))

        // PR merged notifications toggle is reachable in settings
        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        XCTAssertTrue(notificationsTab.waitForExistence(timeout: 3))
        notificationsTab.click()
        let toggle = app.checkBoxes["settings-pr-merged-notifications-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
    }

    // MARK: - Session injection

    private func injectStatusSession() {
        let workspaceDir = GitUITestWorkspace.directoryURL.path
        let json = """
            {
              "tabs": [
                {
                  "id": "\(Self.statusTabID)",
                  "name": "StatusTab",
                  "directory": "\(workspaceDir)",
                  "panes": [
                    {
                      "id": "\(Self.statusPaneID)",
                      "name": "running-pane",
                      "cliType": "claude",
                      "isPriority": false,
                      "isMerged": false,
                      "worktreeDirectory": "\(workspaceDir)",
                      "worktreeIsManaged": false
                    },
                    {
                      "id": "66666666-6666-6666-6666-666666666666",
                      "name": "merged-pane",
                      "cliType": "claude",
                      "isPriority": false,
                      "isMerged": true,
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
        writeSession(json)
    }

    private func injectPRMergedSession() {
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
                      "isMerged": true,
                      "worktreeDirectory": "\(workspaceDir)",
                      "worktreeIsManaged": false
                    }
                  ]
                }
              ],
              "activeTabIndex": 0,
              "pendingNotifications": [
                {
                  "notificationID": "\(Self.notifID)",
                  "paneID": "\(Self.paneID)",
                  "paneName": "test-pane",
                  "tabID": "\(Self.tabID)",
                  "tabName": "TestTab",
                  "isPriority": false,
                  "timestamp": 0,
                  "kind": "prMerged",
                  "prNumber": 1,
                  "prTitle": "Test PR"
                }
              ]
            }
            """
        writeSession(json)
    }

    private func writeSession(_ json: String) {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? json.data(using: .utf8)?.write(to: sessionURL)
    }
}
