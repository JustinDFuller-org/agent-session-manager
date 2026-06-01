import XCTest

/// Covers Git-backed pane routing and worktree cleanup, one app launch per flow.
final class WorktreeFlowTests: BaseTestCase {
    private let primaryCheckoutPaneIdentifier = "UITestWorkspace"
    private let paneWait: TimeInterval = 25

    override func setUp() {
        super.setUp()
        // UITestWorkspace has no remote; "head" avoids origin/<branch> fetch failures
        try? Data("\"head\"".utf8).write(to: UITestAppSupport.directory.appending(path: "worktree-base-ref.json"))
        createTab(named: "RoutingTab")
    }

    func testWorktreeRoutingFlow() {
        // Novel name creates a new worktree without errors
        app.typeKey("p", modifierFlags: .command)
        var nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        let uniqueName = "uitest-pane-\(UUID().uuidString.prefix(8))"
        nameField.click()
        nameField.typeText(uniqueName)
        app.buttons["new-pane-open-button"].click()

        XCTAssertFalse(app.scrollViews["new-pane-worktree-error"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "pane-close-\(uniqueName)").firstMatch
                .waitForExistence(timeout: paneWait))
        XCTAssertFalse(app.textFields["new-pane-name-field"].waitForExistence(timeout: 2))

        // Loose branch resolves via app routing without error
        GitUITestWorkspace.runGitOrFail(["branch", "loose-ui", "HEAD"], cwd: GitUITestWorkspace.directoryURL)
        app.typeKey("p", modifierFlags: .command)
        nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("loose-ui")
        app.buttons["new-pane-open-button"].click()

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "pane-close-loose-ui").firstMatch.waitForExistence(
                timeout: paneWait))
        XCTAssertFalse(app.scrollViews["new-pane-worktree-error"].waitForExistence(timeout: 2))

        // Reuse confirmation: cancel leaves sheet open, continue opens pane
        app.typeKey("p", modifierFlags: .command)
        nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("ui-root")
        app.buttons["new-pane-open-button"].click()

        // Takeover dialog buttons: takeover-cancel-button, takeover-dont-manage-button, takeover-manage-button
        let cancelBtn = app.descendants(matching: .any).matching(identifier: "takeover-cancel-button").firstMatch
        XCTAssertTrue(cancelBtn.waitForExistence(timeout: paneWait))
        cancelBtn.click()
        let dontManageBtn =
            app.descendants(matching: .any).matching(identifier: "takeover-dont-manage-button").firstMatch
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, dontManageBtn.exists || cancelBtn.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertFalse(dontManageBtn.exists || cancelBtn.exists)
        XCTAssertTrue(app.textFields["new-pane-name-field"].waitForExistence(timeout: 3))

        // Now confirm reuse: pane opens on primary checkout
        app.buttons["new-pane-open-button"].click()
        let continueBtn = app.descendants(matching: .any).matching(identifier: "takeover-dont-manage-button").firstMatch
        XCTAssertTrue(continueBtn.waitForExistence(timeout: paneWait))
        continueBtn.click()

        XCTAssertTrue(
            app.staticTexts.matching(identifier: "pane-name-\(primaryCheckoutPaneIdentifier)").firstMatch
                .waitForExistence(timeout: paneWait))
        XCTAssertFalse(app.textFields["new-pane-name-field"].waitForExistence(timeout: 2))

        // Duplicate managed worktree shows error, cancel closes sheet
        // Managed secondary worktrees open directly (isExternalTakeover: false) — no dialog.
        GitUITestWorkspace.addManagedSecondaryWorktree(folder: "wt-dup", newTrackingBranch: "wt-track-dup-ui")
        app.typeKey("p", modifierFlags: .command)
        nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("wt-dup")
        app.buttons["new-pane-open-button"].click()
        XCTAssertTrue(
            app.staticTexts.matching(identifier: "pane-name-wt-dup").firstMatch.waitForExistence(timeout: paneWait))

        // Opening a duplicate pane name triggers inline validation before submit.
        app.typeKey("p", modifierFlags: .command)
        nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("wt-dup")
        let dupError = app.staticTexts["new-pane-name-error"]
        waitFor(dupError)
        XCTAssertFalse(app.buttons["new-pane-open-button"].isEnabled)
        app.buttons["new-pane-cancel-button"].click()
        waitForDisappear(nameField)

        // Managed secondary worktree reuse after confirmation
        GitUITestWorkspace.addManagedSecondaryWorktree(folder: "wt-side", newTrackingBranch: "wt-track-side-ui")
        app.typeKey("p", modifierFlags: .command)
        nameField = app.textFields["new-pane-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("wt-side")
        app.buttons["new-pane-open-button"].click()
        XCTAssertTrue(
            app.staticTexts.matching(identifier: "pane-name-wt-side").firstMatch.waitForExistence(timeout: paneWait))
    }

    func testWorktreeCleanupFlow() {
        // Non-managed pane close shows no cleanup alert.
        // Open primary checkout with "Don't Manage" → worktreeIsManaged = false.
        openPrimaryCheckoutPane()
        let primaryPaneName = app.staticTexts.matching(identifier: "pane-name-UITestWorkspace").firstMatch
        waitFor(primaryPaneName, timeout: paneWait)

        app.descendants(matching: .any).matching(identifier: "pane-close-UITestWorkspace").firstMatch.click()
        screenshot("14-simple-close")

        XCTAssertFalse(app.buttons["Keep Worktree"].firstMatch.waitForExistence(timeout: 2))
        waitForDisappear(primaryPaneName)

        // Managed worktree pane close shows cleanup alert with all three buttons
        createManagedWorktreePane(folder: "wt-alert")
        app.descendants(matching: .any).matching(identifier: "pane-close-wt-alert").firstMatch.click()
        screenshot("15-cleanup-alert")

        let keepButton = app.buttons["Keep Worktree"].firstMatch
        XCTAssertTrue(keepButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete Worktree"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.exists)

        // Dismiss the alert so we can continue
        app.windows.firstMatch.buttons["Cancel"].firstMatch.click()
        waitForDisappear(keepButton)

        // Mixed layout: managed + non-managed — only managed shows cleanup alert
        createManagedWorktreePane(folder: "wt-managed")
        // Re-open primary checkout as non-managed (previous one was closed above)
        openPrimaryCheckoutPane()
        let primaryPaneName2 = app.staticTexts.matching(identifier: "pane-name-UITestWorkspace").firstMatch
        waitFor(primaryPaneName2, timeout: paneWait)

        app.descendants(matching: .any).matching(identifier: "pane-close-UITestWorkspace").firstMatch.click()
        XCTAssertFalse(app.buttons["Keep Worktree"].firstMatch.waitForExistence(timeout: 2))
        waitForDisappear(primaryPaneName2)

        app.descendants(matching: .any).matching(identifier: "pane-close-wt-managed").firstMatch.click()
        screenshot("16-mixed-close")
        XCTAssertTrue(app.buttons["Keep Worktree"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete Worktree"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.exists)
    }

    func testWorktreeDeleteFlowClosesImmediately() {
        createManagedWorktreePane(folder: "wt-immediate")

        let paneLabel = app.staticTexts.matching(identifier: "pane-name-wt-immediate").firstMatch
        XCTAssertTrue(paneLabel.waitForExistence(timeout: paneWait))

        app.descendants(matching: .any).matching(identifier: "pane-close-wt-immediate").firstMatch.click()

        let deleteButton = app.buttons["Delete Worktree"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()

        // Pane must vanish within 2 seconds — confirming it didn't block on git I/O.
        XCTAssertFalse(paneLabel.waitForExistence(timeout: 2))
    }

    func testBaseBranchOverrideCreatesWorktreeFromOverrideBranch() {
        // Create a qa-ui branch in the workspace so the override has a valid base
        GitUITestWorkspace.runGitOrFail(["branch", "qa-ui", "HEAD"], cwd: GitUITestWorkspace.directoryURL)

        // Open New Tab sheet, fill name + directory via UITesting Choose path, and set base branch
        app.typeKey("t", modifierFlags: .command)
        let nameField = app.textFields["new-tab-name-field"]
        waitFor(nameField)
        nameField.click()
        nameField.typeText("OverrideTab")
        app.buttons["new-tab-choose-dir-button"].click()
        waitFor(app.buttons["new-tab-create-button"])
        let baseBranchField = app.textFields["new-tab-base-branch-field"]
        waitFor(baseBranchField)
        baseBranchField.click()
        baseBranchField.typeText("qa-ui")
        app.buttons["new-tab-create-button"].click()
        waitFor(app.buttons["tab-button-OverrideTab"].firstMatch)

        // Open a pane with a novel name — should branch from qa-ui without worktree error
        let uniqueName = "qa-override-\(UUID().uuidString.prefix(8))"
        app.typeKey("p", modifierFlags: .command)
        let paneField = app.textFields["new-pane-name-field"]
        waitFor(paneField)
        paneField.click()
        paneField.typeText(uniqueName)
        app.buttons["new-pane-open-button"].click()

        XCTAssertFalse(app.scrollViews["new-pane-worktree-error"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts.matching(identifier: "pane-name-\(uniqueName)").firstMatch
                .waitForExistence(timeout: paneWait))
    }

    private func openPrimaryCheckoutPane() {
        app.typeKey("p", modifierFlags: .command)
        let field = app.textFields["new-pane-name-field"]
        waitFor(field)
        field.click()
        field.typeText("ui-root")
        app.buttons["new-pane-open-button"].click()
        let dontManage = app.descendants(matching: .any).matching(identifier: "takeover-dont-manage-button").firstMatch
        XCTAssertTrue(dontManage.waitForExistence(timeout: paneWait))
        dontManage.click()
        waitForDisappear(field, timeout: 25)
    }

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
        waitForDisappear(field, timeout: 25)
        waitFor(app.staticTexts.matching(identifier: "pane-name-\(folder)").firstMatch, timeout: 10)
    }
}
