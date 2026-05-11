import XCTest

final class PRMergedNotificationUITests: XCTestCase {
    var app: XCUIApplication!

    private static let tabID = "11111111-1111-1111-1111-111111111111"
    private static let paneID = "22222222-2222-2222-2222-222222222222"
    private static let notifID = "33333333-3333-3333-3333-333333333333"

    private var sessionURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager/sessions.json")
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        GitUITestWorkspace.prepareCleanRepo()
        injectSessionWithPRMergedNotification()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()
    }

    override func tearDown() {
        app.terminate()
        try? FileManager.default.removeItem(at: sessionURL)
        super.tearDown()
    }

    // MARK: - Sidebar rendering

    func testSidebarShowsPRMergedRow() {
        let sidebar = app.scrollViews.firstMatch
        let row = app.buttons["notification-row-test-pane"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Expected notification row for 'test-pane' in sidebar")
    }

    func testSidebarPRMergedRowContainsPRNumber() {
        let row = app.buttons["notification-row-test-pane"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let prText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'PR #1'")).firstMatch
        XCTAssertTrue(prText.waitForExistence(timeout: 3), "Expected 'PR #1 merged' label in sidebar row")
    }

    // MARK: - Action alert

    func testClickingNotificationRowShowsActionAlert() {
        let row = app.buttons["notification-row-test-pane"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()

        let alertTitle = app.staticTexts["PR Merged"]
        XCTAssertTrue(alertTitle.waitForExistence(timeout: 5), "Expected 'PR Merged' alert")
    }

    func testActionAlertHasAllThreeButtons() {
        let row = app.buttons["notification-row-test-pane"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()

        XCTAssertTrue(app.buttons["Close Pane"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close Pane and Clean Up Worktree"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3))
    }

    func testCancelDismissesAlert() {
        let row = app.buttons["notification-row-test-pane"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.click()

        let alertTitle = app.staticTexts["PR Merged"]
        let pred = NSPredicate(format: "exists == false")
        let exp = XCTNSPredicateExpectation(predicate: pred, object: alertTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [exp], timeout: 3), .completed, "Alert should dismiss on Cancel")
    }

    // MARK: - Navigation

    func testClickingNotificationRowNavigatesToCorrectTab() {
        let row = app.buttons["notification-row-test-pane"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()

        // Dismiss the PR Merged alert so we can inspect the tab bar
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.click()

        // The tab associated with the notification ("TestTab") must now be active
        let tabButton = app.buttons["tab-button-TestTab"]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 3))
        XCTAssertEqual(tabButton.value as? String, "active", "TestTab should be the active tab after clicking its notification")
    }

    // MARK: - Settings toggle

    func testPRMergedNotificationsToggleExistsInSettings() {
        app.typeKey(",", modifierFlags: .command)

        let notificationsTab = app.buttons["Notifications"]
        XCTAssertTrue(notificationsTab.waitForExistence(timeout: 3))
        notificationsTab.click()

        let toggle = app.checkBoxes["settings-pr-merged-notifications-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
    }

    // MARK: - Session injection

    private func injectSessionWithPRMergedNotification() {
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
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "agent-session-manager")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? json.data(using: .utf8)?.write(to: sessionURL)
    }
}
