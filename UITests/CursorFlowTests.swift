import XCTest

final class CursorFlowTests: BaseTestCase {
    func testCursorPaneWithAgentControlInjection() throws {
        let shell = Process()
        let output = Pipe()
        shell.executableURL = URL(filePath: "/bin/zsh")
        shell.arguments = ["-i", "-c", "command -v agent"]
        shell.standardOutput = output
        shell.standardError = FileHandle.nullDevice
        try shell.run()
        shell.waitUntilExit()
        guard shell.terminationStatus == 0,
            !output.fileHandleForReading.readDataToEndOfFile().isEmpty
        else {
            throw XCTSkip("Cursor agent is not installed in the UI-test shell PATH")
        }

        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["AgentSessionManager Settings"]
        waitFor(settingsWindow)
        let toolsTab = settingsWindow.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-tools").firstMatch
        waitFor(toolsTab)
        toolsTab.click()

        let cursorTool = settingsWindow.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Cursor'"))
            .firstMatch
        waitFor(cursorTool)
        cursorTool.click()

        let enableCursor = settingsWindow.checkBoxes["settings-tool-enable-toggle-cursor"]
        waitFor(enableCursor)
        if enableCursor.value as? Int != 1 {
            enableCursor.click()
        }
        app.typeKey("w", modifierFlags: .command)
        waitForDisappear(settingsWindow)

        createTab(named: "CursorControlTab")
        app.typeKey("p", modifierFlags: .command)
        let paneField = app.textFields["new-pane-name-field"]
        waitFor(paneField)
        let cursorHarness = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Cursor'"))
            .firstMatch
        waitFor(cursorHarness)
        cursorHarness.click()
        let controlToggle = app.checkBoxes["new-pane-agent-control-toggle"]
        waitFor(controlToggle)
        if controlToggle.value as? Int != 1 {
            controlToggle.click()
        }
        paneField.typeText("cursor-control")
        app.buttons["new-pane-open-button"].click()

        waitForDisappear(paneField, timeout: 25)
        let pane = app.staticTexts["pane-name-cursor-control"].firstMatch
        waitFor(pane, timeout: 15)
        let errorOverlay = app.descendants(matching: .any)
            .matching(identifier: "pane-error-overlay-cursor-control").firstMatch
        if errorOverlay.exists {
            XCTFail(
                "Cursor setup failed: "
                    + app.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | "))
        }

        app.descendants(matching: .any).matching(identifier: "pane-close-cursor-control").firstMatch.click()
        let keepWorktree = app.buttons["Keep Worktree"].firstMatch
        waitFor(keepWorktree)
        keepWorktree.click()
        waitForDisappear(pane, timeout: 10)
    }
}
