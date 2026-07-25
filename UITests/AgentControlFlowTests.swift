import Foundation
import XCTest

final class AgentControlFlowTests: BaseTestCase {
    func testAgentControlSettingsAndNewPaneDecisionFlow() throws {
        app.typeKey(",", modifierFlags: .command)

        let policyPicker = app.descendants(matching: .any)
            .matching(identifier: "settings-agent-control-injection-policy-picker").firstMatch
        let scopePicker = app.descendants(matching: .any)
            .matching(identifier: "settings-agent-control-scope-picker").firstMatch
        waitFor(policyPicker)
        waitFor(scopePicker)

        let globalScope = app.descendants(matching: .any)
            .matching(identifier: "settings-agent-control-scope-option-global").firstMatch
        waitFor(globalScope)

        let tabScope = app.descendants(matching: .any)
            .matching(identifier: "settings-agent-control-scope-option-tab").firstMatch
        waitFor(tabScope)
        tabScope.click()

        policyPicker.click()
        let askOff = policyPicker.menuItems["Ask (off by default)"]
        waitFor(askOff)
        askOff.click()
        app.typeKey("w", modifierFlags: .command)

        createTab(named: "ControlTab")
        app.typeKey("p", modifierFlags: .command)
        let paneField = app.textFields["new-pane-name-field"]
        waitFor(paneField)
        let controlToggle = app.checkBoxes["new-pane-agent-control-toggle"]
        waitFor(controlToggle)
        XCTAssertEqual(controlToggle.value as? Int, 0)
        controlToggle.click()
        XCTAssertEqual(controlToggle.value as? Int, 1)
        paneField.click()
        paneField.typeText("controlled-pane")
        app.buttons["new-pane-open-button"].click()
        waitForDisappear(paneField, timeout: 25)
        waitFor(app.staticTexts["pane-name-controlled-pane"].firstMatch, timeout: 10)

        let sessionURL = UITestAppSupport.directory.appending(path: "sessions.json")
        let sessionData = try Data(contentsOf: sessionURL)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: sessionData) as? [String: Any])
        let tabs = try XCTUnwrap(object["tabs"] as? [[String: Any]])
        let panes = try XCTUnwrap(tabs.first?["panes"] as? [[String: Any]])
        XCTAssertEqual(panes.first?["agentControlInjectionEnabled"] as? Bool, true)
    }

    func testAlwaysAndNeverPoliciesExposeForcedPaneState() {
        app.typeKey(",", modifierFlags: .command)
        let policyPicker = app.descendants(matching: .any)
            .matching(identifier: "settings-agent-control-injection-policy-picker").firstMatch
        waitFor(policyPicker)

        policyPicker.click()
        let always = policyPicker.menuItems["Always"]
        waitFor(always)
        always.click()
        app.typeKey("w", modifierFlags: .command)

        createTab(named: "AlwaysTab")
        app.typeKey("p", modifierFlags: .command)
        let alwaysField = app.textFields["new-pane-name-field"]
        waitFor(alwaysField)
        XCTAssertFalse(app.checkBoxes["new-pane-agent-control-toggle"].exists)
        XCTAssertTrue(app.staticTexts["Agent Session Manager control will be enabled."].exists)
        app.typeKey(.escape, modifierFlags: [])
        waitForDisappear(alwaysField)
    }
}
