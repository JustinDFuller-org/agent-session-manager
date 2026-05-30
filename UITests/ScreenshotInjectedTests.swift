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
        try? FileManager.default.removeItem(at: UITestAppSupport.directory.appending(path: "invariants"))
        super.tearDown()
    }

    func testInvariantDashboardScreenshot() {
        let directory = UITestAppSupport.directory.appending(path: "invariants")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jsonl = """
            {"_type":"metadata","schemaVersion":1}
            {"id":"11111111-1111-1111-1111-111111111111","invariantID":"statusline.worktree.name","integration":"Status Line","severity":"warning","description":"The reported worktree name must match the pane working directory.","timestamp":"2026-05-30T12:00:00Z","context":{"pane.name":"feature-invariants","reported":"wrong-name","computed":"feature-invariants"}}
            {"id":"22222222-2222-2222-2222-222222222222","invariantID":"statusline.lines.source","integration":"Status Line","severity":"warning","description":"Displayed line counts must come from the pane's git diff.","timestamp":"2026-05-30T12:01:00Z","context":{"pane.name":"feature-invariants","reported_added":"3","computed_added":"5"}}
            """
        try? Data(jsonl.utf8).write(to: directory.appending(path: "invariants.jsonl"))

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-skip-restore"]
        app.launch()
        app.activate()
        app.typeKey("i", modifierFlags: [.command, .shift])

        let dashboard = app.windows["Invariant Dashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5))
        XCTAssertTrue(
            dashboard.textFields["invariant-dashboard-filter-field"]
                .waitForExistence(timeout: 5)
        )
        screenshot("invariant-dashboard", app: app)
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
        // Detection runs async with interactive shells; wait for it to finish before screenshotting
        // or clicking (the button is disabled while detecting).
        let enabled = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: doneButton)
        wait(for: [enabled], timeout: 15)
        screenshot("onboarding-tools", app: app)

        doneButton.click()

        let statusLineSkipButton = app.buttons["onboarding-statusline-skip-button"]
        XCTAssertTrue(statusLineSkipButton.waitForExistence(timeout: 10))
        screenshot("onboarding-status-line", app: app)

        // Use Save (not Skip) so the wizard-default rows are persisted to disk.
        // Skip would write an empty config, breaking testPaneStatusScreenshot which
        // relies on a non-empty status line appearing in a subsequent test.
        let statusLineSaveButton = app.buttons["onboarding-statusline-save-button"]
        statusLineSaveButton.click()

        let cliFlagsSaveButton = app.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))
        screenshot("onboarding-cli-flags", app: app)

        cliFlagsSaveButton.click()

        let finishButton = app.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        screenshot("onboarding-profiles", app: app)

        finishButton.click()
    }

    private func writeSupport(json: String) {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? json.data(using: .utf8)?.write(to: sessionURL)
        try? Data("\"head\"".utf8).write(to: worktreeBaseRefURL)
    }
}
