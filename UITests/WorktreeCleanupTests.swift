import XCTest

final class WorktreeCleanupUITests: BaseTestCase {

    private func createManagedWorktreePane(folder: String) {
        GitUITestWorkspace.addManagedSecondaryWorktree(
            folder: folder,
            newTrackingBranch: "track-\(folder)"
        )
        app.typeKey("p", modifierFlags: .command)
        let field = app.textFields["new-pane-name-field"]
        waitFor(field)
        field.click()
        field.typeText(folder)
        app.buttons["new-pane-open-button"].click()
        let proceed = app.buttons["new-pane-reuse-confirm-continue"]
        waitFor(proceed)
        proceed.click()
        waitFor(app.staticTexts[folder].firstMatch)
    }

    func testSimplePaneCloseShowsNoCleanupAlert() {
        createTab(named: "SimpleTab")
        createPane(named: "simple-pane")

        let paneName = app.staticTexts["simple-pane"].firstMatch
        waitFor(paneName)

        app.buttons["close-simple-pane"].firstMatch.click()
        screenshot("14-simple-close")

        XCTAssertFalse(app.buttons["Keep Worktree"].firstMatch.waitForExistence(timeout: 2))
        waitForDisappear(paneName)
    }

    func testManagedPaneCloseShowsCleanupAlert() {
        createTab(named: "CleanupTab")
        createManagedWorktreePane(folder: "wt-alert")

        app.buttons["close-wt-alert"].firstMatch.click()
        screenshot("15-cleanup-alert")

        let keepButton = app.buttons["Keep Worktree"].firstMatch
        XCTAssertTrue(keepButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete Worktree"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.exists)
    }

    func testCleanupAlertOnlyForManagedWorktrees() {
        createTab(named: "MixedTab")
        createManagedWorktreePane(folder: "wt-managed")
        createPane(named: "simple-pane")

        app.buttons["close-simple-pane"].firstMatch.click()
        XCTAssertFalse(app.buttons["Keep Worktree"].firstMatch.waitForExistence(timeout: 2))
        let simplePaneName = app.staticTexts["simple-pane"].firstMatch
        waitForDisappear(simplePaneName)

        app.buttons["close-wt-managed"].firstMatch.click()
        screenshot("16-mixed-close")
        XCTAssertTrue(app.buttons["Keep Worktree"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete Worktree"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.exists)
    }
}
