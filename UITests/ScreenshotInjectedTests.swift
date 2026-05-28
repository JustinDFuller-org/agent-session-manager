import XCTest

/// Screenshot tests that require pre-injected session state. Does not extend BaseTestCase
/// because each test controls its own launch arguments and injected JSON.
final class ScreenshotInjectedTests: XCTestCase {
    var app: XCUIApplication!

    private static let tabID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    private static let runningPaneID = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    private static let mergedPaneID = "cccccccc-cccc-cccc-cccc-cccccccccccc"
    private static let notifTabID = "dddddddd-dddd-dddd-dddd-dddddddddddd"
    private static let notifPaneID = "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"
    private static let notifID = "ffffffff-ffff-ffff-ffff-ffffffffffff"

    private var sessionURL: URL {
        UITestAppSupport.directory.appending(path: "sessions.json")
    }

    private var worktreeBaseRefURL: URL {
        UITestAppSupport.directory.appending(path: "worktree-base-ref.json")
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        GitUITestWorkspace.prepareCleanRepo()
    }

    override func tearDown() {
        app?.terminate()
        try? FileManager.default.removeItem(at: sessionURL)
        try? FileManager.default.removeItem(at: worktreeBaseRefURL)
        super.tearDown()
    }

    func testPaneStatusScreenshot() {
        let workspaceDir = GitUITestWorkspace.directoryURL.path
        let json = """
            {
              "tabs": [
                {
                  "id": "\(Self.tabID)",
                  "name": "StatusTab",
                  "directory": "\(workspaceDir)",
                  "panes": [
                    {
                      "id": "\(Self.runningPaneID)",
                      "name": "running-pane",
                      "cliType": "claude",
                      "isPriority": false,
                      "isMerged": false,
                      "worktreeDirectory": "\(workspaceDir)",
                      "worktreeIsManaged": false
                    },
                    {
                      "id": "\(Self.mergedPaneID)",
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
        writeSupport(json: json)

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()

        let runningDot = app.descendants(matching: .any).matching(identifier: "pane-status-dot-running-pane").firstMatch
        XCTAssertTrue(runningDot.waitForExistence(timeout: 15))
        let statusLineRow = app.descendants(matching: .any).matching(identifier: "status-line-row").firstMatch
        XCTAssertTrue(statusLineRow.waitForExistence(timeout: 5))
        screenshot("pane-status-indicators", app: app)
    }

    func testNotificationSidebarScreenshot() {
        let workspaceDir = GitUITestWorkspace.directoryURL.path
        let json = """
            {
              "tabs": [
                {
                  "id": "\(Self.notifTabID)",
                  "name": "TestTab",
                  "directory": "\(workspaceDir)",
                  "panes": [
                    {
                      "id": "\(Self.notifPaneID)",
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
                  "paneID": "\(Self.notifPaneID)",
                  "paneName": "test-pane",
                  "tabID": "\(Self.notifTabID)",
                  "tabName": "TestTab",
                  "isPriority": false,
                  "timestamp": 0,
                  "kind": "prMerged",
                  "prNumber": 42,
                  "prTitle": "Add screenshot coverage"
                }
              ]
            }
            """
        writeSupport(json: json)

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.activate()

        let row = app.descendants(matching: .any).matching(identifier: "notification-row-test-pane").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        screenshot("notification-sidebar", app: app)

        row.click()
        let alertTitle = app.staticTexts["PR Merged"]
        XCTAssertTrue(alertTitle.waitForExistence(timeout: 5))
        screenshot("pr-merged-alert", app: app)
    }

    func testOnboardingWizardScreenshots() {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--uitesting-skip-restore", "--uitesting-show-onboarding",
        ]
        app.launch()
        app.activate()

        let setupButton = app.buttons["onboarding-setup-button"]
        XCTAssertTrue(setupButton.waitForExistence(timeout: 5))
        screenshot("onboarding-welcome", app: app)

        setupButton.click()

        let shellPicker = app.popUpButtons["onboarding-shell-picker"]
        XCTAssertTrue(shellPicker.waitForExistence(timeout: 5))
        screenshot("onboarding-shell", app: app)

        let continueButton = app.buttons["onboarding-shell-continue-button"]
        continueButton.click()

        let doneButton = app.buttons["onboarding-done-button"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        screenshot("onboarding-tools", app: app)
    }

    private func writeSupport(json: String) {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? json.data(using: .utf8)?.write(to: sessionURL)
        try? Data("\"head\"".utf8).write(to: worktreeBaseRefURL)
    }
}
