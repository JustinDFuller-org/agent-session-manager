import XCTest

/// Covers Claude **New Pane** smart routing (`classifyClaudePaneIntent`), reuse confirmation, and Git-backed paths.
///
/// Depends on **`GitUITestWorkspace`** preparing a repo in `BaseTestCase.setUp`.
final class NewPaneWorktreeRoutingTests: BaseTestCase {

    /// Primary checkout resolves to pane title **`UITestWorkspace`** (folder name), not branch `ui-root`.
    private let primaryCheckoutPaneIdentifier = "UITestWorkspace"

    private let paneWait: TimeInterval = 25

    override func setUp() {
        super.setUp()
        createTab(named: "RoutingTab")
    }

    func testNovelPaneNameOpensWithoutGitError() {
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        let unique = "uitest-pane-\(UUID().uuidString.prefix(8))"
        nameField.click()
        nameField.typeText(unique)

        app.buttons["new-pane-open-button"].click()

        let scrollErr = app.scrollViews["new-pane-worktree-error"]
        XCTAssertFalse(scrollErr.waitForExistence(timeout: 2), "unexpected worktree setup error")

        let header = app.groups["pane-header-\(unique)"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: paneWait))

        XCTAssertFalse(app.textFields["new-pane-name-field"].waitForExistence(timeout: 2), "sheet should dismiss")
    }

    func testLooseBranchCreatesPaneViaResolveViaApp() {
        GitUITestWorkspace.addLooseBranch(named: "loose-ui")

        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("loose-ui")

        app.buttons["new-pane-open-button"].click()

        let header = app.groups["pane-header-loose-ui"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: paneWait))

        let errStatic = app.scrollViews["new-pane-worktree-error"]
        XCTAssertFalse(errStatic.waitForExistence(timeout: 2))
    }

    func testReuseConfirmationContinueOpensPrimaryCheckoutPane() {
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("ui-root")

        app.buttons["new-pane-open-button"].click()

        let proceed = app.buttons["new-pane-reuse-confirm-continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: paneWait))
        proceed.click()

        let header = app.groups["pane-header-\(primaryCheckoutPaneIdentifier)"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: paneWait))
        XCTAssertFalse(app.textFields["new-pane-name-field"].waitForExistence(timeout: 2))
    }

    func testReuseConfirmationCancelLeavesSheetOpen() {
        app.typeKey("p", modifierFlags: .command)
        let nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        let typed = "ui-root"
        nameField.click()
        nameField.typeText(typed)

        app.buttons["new-pane-open-button"].click()

        let cancel = app.buttons["new-pane-reuse-confirm-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: paneWait))
        cancel.click()

        XCTAssertTrue(waitForReuseDialogDismissed(timeout: 5))

        let fieldAgain = app.textFields["new-pane-name-field"]
        XCTAssertTrue(fieldAgain.waitForExistence(timeout: 3))
    }

    func testDuplicateManagedCheckoutShowsError() {
        GitUITestWorkspace.addManagedSecondaryWorktree(folder: "wt-dup", newTrackingBranch: "wt-track-dup-ui")

        app.typeKey("p", modifierFlags: .command)
        let field1 = app.textFields["new-pane-name-field"]
        waitFor(field1)
        field1.click()
        field1.typeText("wt-dup")

        app.buttons["new-pane-open-button"].click()
        XCTAssertTrue(app.buttons["new-pane-reuse-confirm-continue"].waitForExistence(timeout: paneWait))
        app.buttons["new-pane-reuse-confirm-continue"].click()

        let header = app.groups["pane-header-wt-dup"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: paneWait))

        app.typeKey("p", modifierFlags: .command)
        let field2 = app.textFields["new-pane-name-field"]
        waitFor(field2)
        field2.click()
        field2.typeText("wt-dup")

        app.buttons["new-pane-open-button"].click()

        let errScroll = app.scrollViews["new-pane-worktree-error"]
        XCTAssertTrue(errScroll.waitForExistence(timeout: paneWait))
        let errLabel = errScroll.staticTexts.element(boundBy: 0).label
        XCTAssertTrue(errLabel.contains("already open"))

        XCTAssertTrue(app.buttons["new-pane-cancel-button"].exists)
        app.buttons["new-pane-cancel-button"].click()
    }

    func testReuseManagedSecondaryWorktreeAfterConfirmation() {
        GitUITestWorkspace.addManagedSecondaryWorktree(folder: "wt-side", newTrackingBranch: "wt-track-side-ui")

        app.typeKey("p", modifierFlags: .command)
        let field = app.textFields["new-pane-name-field"]
        waitFor(field)
        field.click()
        field.typeText("wt-side")

        app.buttons["new-pane-open-button"].click()

        XCTAssertTrue(app.buttons["new-pane-reuse-confirm-continue"].waitForExistence(timeout: paneWait))
        app.buttons["new-pane-reuse-confirm-continue"].click()

        let header = app.groups["pane-header-wt-side"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: paneWait))
    }

    /// Reuse dialogs can appear as descendant buttons; polling covers SwiftUI variance.
    private func waitForReuseDialogDismissed(timeout: TimeInterval) -> Bool {
        let continueBtn = app.buttons["new-pane-reuse-confirm-continue"]
        let cancelBtn = app.buttons["new-pane-reuse-confirm-cancel"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !continueBtn.exists && !cancelBtn.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }
}
