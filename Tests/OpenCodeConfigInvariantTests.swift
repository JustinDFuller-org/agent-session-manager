import XCTest

@testable import AgentSessionManager

@MainActor
final class OpenCodeConfigInvariantTests: XCTestCase {
    override func setUp() {
        super.setUp()
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
    }

    override func tearDown() {
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
        super.tearDown()
    }

    func testUserProvidedConfigContentTriggersInvariant() {
        InvariantReporter.shared.enableTestCapture()
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))

        _ = tab.addPane(
            name: "opencode-pane",
            harness: .opencode,
            extraEnvVars: ["OPENCODE_CONFIG_CONTENT": "{\"share\":\"auto\"}"]
        )

        let violation = InvariantReporter.shared.violationsForTesting.first
        XCTAssertEqual(violation?.invariantID, "opencode.config_content.app_controlled")
        XCTAssertTrue(violation?.context["overridden_keys"]?.contains("OPENCODE_CONFIG_CONTENT") == true)
    }

    func testUserProvidedPermissionTriggersInvariant() {
        InvariantReporter.shared.enableTestCapture()
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))

        _ = tab.addPane(
            name: "opencode-pane",
            harness: .opencode,
            extraEnvVars: ["OPENCODE_PERMISSION": "{\"bash\":\"allow\"}"]
        )

        let violation = InvariantReporter.shared.violationsForTesting.first
        XCTAssertEqual(violation?.invariantID, "opencode.config_content.app_controlled")
        XCTAssertTrue(violation?.context["overridden_keys"]?.contains("OPENCODE_PERMISSION") == true)
    }

    func testNoAppControlledEnvVarsDoesNotTriggerInvariant() {
        InvariantReporter.shared.enableTestCapture()
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))

        _ = tab.addPane(
            name: "opencode-pane",
            harness: .opencode,
            extraEnvVars: ["OPENCODE_CLIENT": "agent-session-manager"]
        )

        XCTAssertTrue(InvariantReporter.shared.violationsForTesting.isEmpty)
    }

    func testAppInjectsConfigContentDespiteUserOverride() {
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))
        let pane = tab.addPane(
            name: "opencode-pane",
            harness: .opencode,
            extraEnvVars: ["OPENCODE_CONFIG_CONTENT": "{\"share\":\"auto\"}"]
        )

        let entries = pane.terminalController?.pendingEnvironment?
            .filter { $0.hasPrefix("OPENCODE_CONFIG_CONTENT=") }
        XCTAssertEqual(entries?.count, 2, "User and app entries should both be present")
        XCTAssertTrue(entries?.last?.contains("\"share\":\"manual\"") == true, "App value should be last so it wins")
    }
}
