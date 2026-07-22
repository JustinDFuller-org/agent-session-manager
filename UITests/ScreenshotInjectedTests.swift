import XCTest

/// Screenshot tests that require pre-injected session state. Does not extend BaseTestCase
/// because each test controls its own launch arguments and injected JSON.
final class ScreenshotInjectedTests: XCTestCase {
    var app: XCUIApplication!

    private static let notifTabID = "dddddddd-dddd-dddd-dddd-dddddddddddd"
    private static let notifPaneID = "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"
    private static let notifID = "ffffffff-ffff-ffff-ffff-ffffffffffff"
    private static let activityTabID = "10000000-0000-0000-0000-000000000000"
    private static let idlePaneID = "11000000-0000-0000-0000-000000000000"
    private static let workingPaneID = "22000000-0000-0000-0000-000000000000"
    private static let waitingPaneID = "33000000-0000-0000-0000-000000000000"
    private static let waitingNotifID = "34000000-0000-0000-0000-000000000000"

    private var sessionURL: URL {
        UITestAppSupport.directory.appending(path: "sessions.json")
    }

    private var worktreeBaseRefURL: URL {
        UITestAppSupport.directory.appending(path: "worktree-base-ref.json")
    }

    private var activityIndicatorSettingsURL: URL {
        UITestAppSupport.directory.appending(path: "activity-indicator-settings.json")
    }

    private func clearPersistedState() {
        let support = UITestAppSupport.directory
        for file in [
            "sessions.json", "settings.json", "codex-settings.json",
            "cursor-settings.json", "opencode-settings.json", "opencode-env-var-settings.json",
            "statusline-settings.json",
            "active-tools-settings.json", "default-branch.json",
            "notification-settings.json", "restart-settings.json",
            "worktree-cleanup.json", "existing-worktree-management.json",
            "debug-settings.json", "pr-tracking-settings.json",
            "tracing-settings.json", "pr-polling-settings.json",
            "terminal-settings.json", "worktree-base-ref.json", "exit-behavior.json",
            "env-var-settings.json", "profiles.json", "session-name-settings.json",
            "shell-settings.json", "onboarding-settings.json",
            "activity-indicator-settings.json", "focus-mode-settings.json",
            "agent-control-settings.json",
        ] {
            try? FileManager.default.removeItem(at: support.appending(path: file))
        }
        try? FileManager.default.removeItem(at: support.appending(path: "traces"))
        try? FileManager.default.removeItem(at: support.appending(path: "invariants"))
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        clearPersistedState()
        GitUITestWorkspace.prepareCleanRepo()
    }

    override func tearDown() {
        app?.terminate()
        clearPersistedState()
        super.tearDown()
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

    func testActivityIndicatorStatesScreenshot() {
        let workspaceDir = GitUITestWorkspace.directoryURL.path
        let json = """
            {
              "tabs": [
                {
                  "id": "\(Self.activityTabID)",
                  "name": "Activity States",
                  "directory": "\(workspaceDir)",
                  "panes": [
                    {
                      "id": "\(Self.idlePaneID)",
                      "name": "idle-pane",
                      "cliType": "claude",
                      "isPriority": false,
                      "isMerged": false,
                      "worktreeDirectory": "\(workspaceDir)",
                      "worktreeIsManaged": false
                    },
                    {
                      "id": "\(Self.workingPaneID)",
                      "name": "working-pane",
                      "cliType": "claude",
                      "isPriority": false,
                      "isMerged": false,
                      "worktreeDirectory": "\(workspaceDir)",
                      "worktreeIsManaged": false
                    },
                    {
                      "id": "\(Self.waitingPaneID)",
                      "name": "waiting-pane",
                      "cliType": "claude",
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
                  "notificationID": "\(Self.waitingNotifID)",
                  "paneID": "\(Self.waitingPaneID)",
                  "paneName": "waiting-pane",
                  "tabID": "\(Self.activityTabID)",
                  "tabName": "Activity States",
                  "isPriority": false,
                  "timestamp": 0,
                  "kind": "terminalBell"
                }
              ]
            }
            """
        writeSupport(json: json)

        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--inject-pane-working=\(Self.workingPaneID)",
        ]
        app.launch()
        app.activate()

        let descendants = app.descendants(matching: .any)
        XCTAssertTrue(
            descendants.matching(identifier: "pane-activity-idle-idle-pane").firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(
            descendants.matching(identifier: "pane-activity-working-working-pane").firstMatch.waitForExistence(
                timeout: 5))
        XCTAssertTrue(
            descendants.matching(identifier: "pane-activity-waiting-waiting-pane").firstMatch.waitForExistence(
                timeout: 5))
        screenshot("activity-indicator-states", app: app)
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

        let onboardingSheet = app.sheets.firstMatch
        XCTAssertTrue(onboardingSheet.waitForExistence(timeout: 5))

        let statusLineSkipButton = app.buttons["onboarding-statusline-skip-button"]
        XCTAssertTrue(statusLineSkipButton.waitForExistence(timeout: 10))
        let statusLineToggle = app.descendants(matching: .any)
            .matching(identifier: "settings-statusline-percentages-text-toggle").firstMatch
        XCTAssertTrue(statusLineToggle.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(onboardingSheet.frame.width, 520)
        XCTAssertGreaterThan(onboardingSheet.frame.height, 360)
        screenshot("onboarding-status-line", app: app)

        // Use Save (not Skip) so the wizard-default rows are persisted to disk.
        let statusLineSaveButton = app.buttons["onboarding-statusline-save-button"]
        let statusLineSaveHittable = expectation(
            for: NSPredicate(format: "hittable == true"),
            evaluatedWith: statusLineSaveButton)
        wait(for: [statusLineSaveHittable], timeout: 5)
        statusLineSaveButton.click()

        let cliFlagsSaveButton = app.buttons["onboarding-cliflags-save-button"]
        XCTAssertTrue(cliFlagsSaveButton.waitForExistence(timeout: 5))
        let cliFlagsSaveHittable = expectation(
            for: NSPredicate(format: "hittable == true"),
            evaluatedWith: cliFlagsSaveButton)
        wait(for: [cliFlagsSaveHittable], timeout: 5)
        let cliOptionToggle = app.descendants(matching: .any)
            .matching(identifier: "settings-cli-option-show---continue").firstMatch
        XCTAssertTrue(cliOptionToggle.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(onboardingSheet.frame.width, 520)
        XCTAssertGreaterThan(onboardingSheet.frame.height, 360)
        screenshot("onboarding-cli-flags", app: app)

        cliFlagsSaveButton.click()

        let finishButton = app.buttons["onboarding-profiles-finish-button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        let newProfileButton = app.descendants(matching: .any)
            .matching(identifier: "profile-new-button").firstMatch
        XCTAssertTrue(newProfileButton.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(onboardingSheet.frame.width, 520)
        XCTAssertGreaterThan(onboardingSheet.frame.height, 360)
        screenshot("onboarding-profiles", app: app)

        finishButton.click()
    }

    private func writeSupport(json: String) {
        let support = UITestAppSupport.directory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? json.data(using: .utf8)?.write(to: sessionURL)
        try? Data("\"head\"".utf8).write(to: worktreeBaseRefURL)
        try? Data(#"{"enabled":true}"#.utf8).write(to: activityIndicatorSettingsURL)
    }
}
