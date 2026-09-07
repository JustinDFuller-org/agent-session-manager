import XCTest

final class InjectedStateFlowTests: XCTestCase {
    var app: XCUIApplication!

    private static let tabID = "11111111-1111-1111-1111-111111111111"
    private static let paneID = "22222222-2222-2222-2222-222222222222"
    private static let notifID = "33333333-3333-3333-3333-333333333333"

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

    func testPRMergedNotificationFlow() {
        let workspaceDir = GitUITestWorkspace.directoryURL.path
        writeSession(
            """
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
                      "harness": "claude",
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
            """)
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()

        let row = app.descendants(matching: .any).matching(identifier: "notification-row-test-pane").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["TestTab / test-pane"].exists)
        XCTAssertTrue(app.staticTexts["PR #1 merged"].exists)

        row.click()
        let alertTitle = app.staticTexts["PR Merged"]
        XCTAssertTrue(alertTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close Pane"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close Pane and Clean Up Worktree"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3))

        let cancelButton = app.windows.firstMatch.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.click()
        let alertPred = NSPredicate(format: "exists == false")
        let alertExp = XCTNSPredicateExpectation(predicate: alertPred, object: alertTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [alertExp], timeout: 3), .completed)

        let tabButton = app.buttons.matching(identifier: "tab-button-TestTab").firstMatch
        XCTAssertTrue(tabButton.waitForExistence(timeout: 3))
        XCTAssertEqual(tabButton.value as? String, "active")

        let idleDot = app.descendants(matching: .any).matching(identifier: "pane-activity-idle-test-pane").firstMatch
        XCTAssertTrue(idleDot.waitForExistence(timeout: 3))

        app.typeKey(",", modifierFlags: .command)
        let notificationsTab = app.buttons["Notifications"]
        XCTAssertTrue(notificationsTab.waitForExistence(timeout: 3))
        notificationsTab.click()
        let toggle = app.checkBoxes["settings-pr-merged-notifications-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
    }

    func testRegularNotificationReasonFlow() {
        let workspaceDir = GitUITestWorkspace.directoryURL.path
        writeSession(
            """
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
              "pendingNotifications": [
                {
                  "notificationID": "\(Self.notifID)",
                  "paneID": "\(Self.paneID)",
                  "paneName": "test-pane",
                  "tabID": "\(Self.tabID)",
                  "tabName": "TestTab",
                  "isPriority": false,
                  "timestamp": 0,
                  "kind": "terminalBell",
                  "reason": "Permission needed for Bash"
                }
              ]
            }
            """)
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()

        XCTAssertTrue(app.staticTexts["TestTab / test-pane"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Permission needed for Bash"].exists)
    }

    private func writeSession(_ json: String) {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? json.data(using: .utf8)?.write(to: sessionURL)
    }
}
