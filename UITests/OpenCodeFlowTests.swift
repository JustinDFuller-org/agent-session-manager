import XCTest

final class OpenCodeFlowTests: BaseTestCase {
    func testOpenCodePaneFlow() throws {
        let shell = Process()
        let output = Pipe()
        shell.executableURL = URL(filePath: "/bin/zsh")
        shell.arguments = ["-i", "-c", "command -v opencode"]
        shell.standardOutput = output
        shell.standardError = FileHandle.nullDevice
        try shell.run()
        shell.waitUntilExit()
        guard shell.terminationStatus == 0,
            !output.fileHandleForReading.readDataToEndOfFile().isEmpty
        else {
            throw XCTSkip("OpenCode is not installed in the UI-test shell PATH")
        }

        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["AgentSessionManager Settings"]
        waitFor(settingsWindow)
        let toolsTab = settingsWindow.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-tools").firstMatch
        waitFor(toolsTab)
        toolsTab.click()

        let openCodeTool = settingsWindow.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'OpenCode'"))
            .firstMatch
        waitFor(openCodeTool)
        openCodeTool.click()

        let enableOpenCode = settingsWindow.checkBoxes["settings-tool-enable-toggle-opencode"]
        waitFor(enableOpenCode)
        if enableOpenCode.value as? Int != 1 {
            enableOpenCode.click()
        }
        app.typeKey("w", modifierFlags: .command)
        waitForDisappear(settingsWindow)

        createTab(named: "OpenCodeTab")

        app.typeKey("p", modifierFlags: .command)
        let paneSheet = app.textFields["new-pane-name-field"]
        waitFor(paneSheet)
        let openCodeHarness = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'OpenCode'"))
            .firstMatch
        waitFor(openCodeHarness)
        openCodeHarness.click()
        paneSheet.typeText("opencode-smoke")
        app.buttons["new-pane-open-button"].click()

        waitForDisappear(paneSheet, timeout: 25)
        waitFor(app.staticTexts["pane-name-opencode-smoke"].firstMatch, timeout: 10)
    }
}
