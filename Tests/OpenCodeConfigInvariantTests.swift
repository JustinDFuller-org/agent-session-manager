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

    func testOpenCodePortPolicyInvariantPassesOnNormalLaunch() {
        InvariantReporter.shared.enableTestCapture()
        TracingService.shared.enableTestCapture()
        let tab = Tab(name: "repo", directory: URL(filePath: "/tmp/repo"))

        _ = tab.addPane(
            name: "opencode-pane",
            harness: .opencode,
            extraEnvVars: [:]
        )

        XCTAssertFalse(
            InvariantReporter.shared.violationsForTesting.contains { $0.invariantID == "opencode.port.policy" }
        )

        let events = TracingService.shared.recordedEventsForTesting
        XCTAssertTrue(events.contains { $0.name == "opencode.port.allocated" })
        XCTAssertTrue(events.contains { $0.name == "opencode.command.built" })
        let commandBuilt = events.first { $0.name == "opencode.command.built" }
        XCTAssertEqual(commandBuilt?.attributes["hostname"], "127.0.0.1")
        XCTAssertEqual(commandBuilt?.attributes["mdns"], "false")
        XCTAssertEqual(commandBuilt?.attributes["has_port"], "true")
    }
}
