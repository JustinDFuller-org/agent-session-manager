import XCTest

final class OhMyPiFlowTests: BaseTestCase {
    func testOhMyPiPaneFlow() throws {
        let shell = Process()
        let output = Pipe()
        shell.executableURL = URL(filePath: "/bin/zsh")
        shell.arguments = ["-i", "-c", "command -v omp"]
        shell.standardOutput = output
        shell.standardError = FileHandle.nullDevice
        try shell.run()
        shell.waitUntilExit()
        guard shell.terminationStatus == 0,
            !output.fileHandleForReading.readDataToEndOfFile().isEmpty
        else {
            throw XCTSkip("Oh My Pi is not installed in the UI-test shell PATH")
        }

        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["AgentSessionManager Settings"]
        waitFor(settingsWindow)
        let toolsTab = settingsWindow.descendants(matching: .any)
            .matching(identifier: "settings-sidebar-tools").firstMatch
        waitFor(toolsTab)
        toolsTab.click()

        let ohMyPiTool = settingsWindow.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Oh My Pi'"))
            .firstMatch
        waitFor(ohMyPiTool)
        ohMyPiTool.click()

        let enableOhMyPi = settingsWindow.checkBoxes["settings-tool-enable-toggle-omp"]
        waitFor(enableOhMyPi)
        if enableOhMyPi.value as? Int != 1 {
            enableOhMyPi.click()
        }
        app.typeKey("w", modifierFlags: .command)
        waitForDisappear(settingsWindow)

        createTab(named: "OhMyPiTab")

        app.typeKey("p", modifierFlags: .command)
        let paneSheet = app.textFields["new-pane-name-field"]
        waitFor(paneSheet)
        let ohMyPiHarness = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Oh My Pi'"))
            .firstMatch
        waitFor(ohMyPiHarness)
        ohMyPiHarness.click()
        paneSheet.typeText("omp-smoke")
        app.buttons["new-pane-open-button"].click()

        waitForDisappear(paneSheet, timeout: 25)
        waitFor(app.staticTexts["pane-name-omp-smoke"].firstMatch, timeout: 10)
    }
}
