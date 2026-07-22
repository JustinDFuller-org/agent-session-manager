import Foundation
import XCTest

@testable import AgentSessionManager

@MainActor
final class AgentControlPersistenceTests: XCTestCase {
    private let testDirectory = "agent-control-tests-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        PersistenceHelpers.overrideAppSupportSubdirectory = testDirectory
    }

    override func tearDown() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: base.appending(path: testDirectory))
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        TracingService.shared.resetForTesting()
        super.tearDown()
    }

    func testDefaultsMatchAgentControlContract() {
        let settings = AppSettings()

        XCTAssertEqual(settings.agentControlInjectionPolicy, .askOn)
        XCTAssertEqual(settings.agentControlScope, .pane)
        XCTAssertTrue(settings.resolvedAgentControlInjectionDecision(persistedDecision: nil))
    }

    func testPolicyResolutionHonorsGlobalOverridesAndAskDefaults() {
        XCTAssertTrue(AgentControlInjectionPolicy.always.resolve(persistedDecision: false))
        XCTAssertFalse(AgentControlInjectionPolicy.never.resolve(persistedDecision: true))
        XCTAssertTrue(AgentControlInjectionPolicy.askOn.resolve(persistedDecision: nil))
        XCTAssertFalse(AgentControlInjectionPolicy.askOff.resolve(persistedDecision: nil))
        XCTAssertFalse(AgentControlInjectionPolicy.askOn.resolve(persistedDecision: false))
        XCTAssertTrue(AgentControlInjectionPolicy.askOff.resolve(persistedDecision: true))
    }

    func testAgentControlSettingsRoundTrip() throws {
        let original = AgentControlSettings(injectionPolicy: .never, scope: .global)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentControlSettings.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testAgentControlSettingsMissingFieldsUseDefaults() throws {
        let decoded = try JSONDecoder().decode(AgentControlSettings.self, from: Data("{}".utf8))

        XCTAssertEqual(decoded, AgentControlSettings())
    }

    func testSettingsPersistenceRoundTrip() {
        let settings = AppSettings()
        settings.agentControlInjectionPolicy = .askOff
        settings.agentControlScope = .tab
        SettingsPersistence.saveAgentControlSettings(appSettings: settings)

        let decoded = SettingsPersistence.load(AgentControlSettings.self, from: "agent-control-settings.json")

        XCTAssertEqual(decoded?.injectionPolicy, .askOff)
        XCTAssertEqual(decoded?.scope, .tab)
    }

    func testPersistedPaneDecisionRoundTripAndLegacyDefault() throws {
        let persisted = PersistedPane(
            id: UUID(), name: "pane", harness: .claude, agentControlInjectionEnabled: false)
        let decoded = try JSONDecoder().decode(
            PersistedPane.self, from: JSONEncoder().encode(persisted))
        XCTAssertEqual(decoded.agentControlInjectionEnabled, false)

        let legacyJSON = """
            {
              "id":"00000000-0000-0000-0000-000000000001",
              "name":"pane",
              "harness":"claude",
              "isPriority":false,
              "worktreeIsManaged":false
            }
            """
        let legacy = try JSONDecoder().decode(PersistedPane.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(legacy.agentControlInjectionEnabled)
    }

    func testPersistedSessionCarriesPaneDecision() {
        let appState = AppState()
        let tab = Tab(name: "Tab", directory: URL(filePath: "/tmp"))
        let pane = tab.addPane(
            name: "Pane", worktreeDirectory: URL(filePath: "/tmp"), agentControlInjectionEnabled: false)
        appState.tabs = [tab]

        let session = SessionPersistence.makePersistedSession(appState: appState)

        XCTAssertEqual(session.tabs.first?.panes.first?.agentControlInjectionEnabled, false)
        pane.terminalController?.terminate()
    }

    func testPaneDecisionTelemetryIsBoundedAndPaneScoped() {
        TracingService.shared.enableTestCapture()
        let tab = Tab(name: "Tab", directory: URL(filePath: "/tmp"))
        _ = tab.addPane(
            name: "Pane", worktreeDirectory: URL(filePath: "/tmp"), agentControlInjectionEnabled: false)

        let event = TracingService.shared.recordedEventsForTesting.first {
            $0.name == "agent_control.injection_decision.resolved"
        }
        XCTAssertEqual(event?.attributes["agent_control.enabled"], "false")
        XCTAssertEqual(event?.attributes["agent_control.source"], "pane_added")
        XCTAssertNotNil(event?.attributes["pane.id"])
        XCTAssertNotNil(event?.attributes["tab.id"])
        XCTAssertNil(event?.attributes["token"])
        XCTAssertNil(event?.attributes["environment"])
    }
}
