import Foundation
import Testing

@testable import AgentSessionManager

@Suite("ProfileEditorHiddenOptions")
struct ProfileEditorHiddenOptionsTests {
    @Test("profile with hidden-but-enabled option round-trips via JSON")
    func hiddenEnabledOptionRoundTrips() throws {
        let profile = Profile(
            name: "Hidden Test",
            harness: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--verbose", isEnabled: true, value: nil),
                ProfileCLIOption(id: "--bare", isEnabled: true, value: nil),
            ]
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        #expect(decoded.cliOptions.count == 2)
        #expect(decoded.cliOptions.first { $0.id == "--verbose" }?.isEnabled == true)
        #expect(decoded.cliOptions.first { $0.id == "--bare" }?.isEnabled == true)
    }

    @Test("onAddToGlobal sets isAvailable to true on the correct option")
    func onAddToGlobalSetsIsAvailable() {
        var option = CLIOptionConfig(
            id: "--verbose", label: "Verbose", description: "Verbose logging",
            isAvailable: false, isDefaultEnabled: false
        )
        #expect(option.isAvailable == false)
        option.isAvailable = true
        #expect(option.isAvailable == true)
    }

    @Test("persisted option drafts retain values and show-on-create state")
    func persistedOptionDraftRetainsState() {
        let option = CLIOptionConfig.cursorAll.first { $0.id == "--model" }!
        let persisted = ProfileCLIOption(
            id: option.id,
            isEnabled: true,
            value: "cursor-model",
            showOnPaneCreate: true
        )

        let draft = persisted.draft(using: option)

        #expect(draft.enabled == true)
        #expect(draft.value == "cursor-model")
        #expect(draft.showOnPaneCreate == true)
    }

    @Test("profile with hidden env var enabled round-trips via JSON")
    func hiddenEnvVarRoundTrips() throws {
        let profile = Profile(
            name: "Env Test",
            harness: .claude,
            cliOptions: [],
            envVars: [
                ProfileEnvVar(id: "ANTHROPIC_MODEL", isEnabled: true, value: "claude-sonnet-4-6")
            ]
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        #expect(decoded.envVars.count == 1)
        #expect(decoded.envVars.first?.isEnabled == true)
        #expect(decoded.envVars.first?.value == "claude-sonnet-4-6")
    }

    @Test("hidden model options are preserved for every non-Claude harness")
    func hiddenModelOptionsArePreservedAcrossHarnesses() {
        for harness in [Harness.codex, .cursor, .opencode] {
            guard let model = CLIOptionConfig.catalog(for: harness).first(where: { $0.id == "--model" }) else {
                Issue.record("Missing --model option for \(harness)")
                continue
            }

            var hiddenModel = model
            hiddenModel.isAvailable = false
            let states = [
                hiddenModel.id: ProfileOptionDraft(
                    enabled: true,
                    value: "\(harness.rawValue)-model",
                    showOnPaneCreate: true
                )
            ]

            let options = ProfileSnapshotBuilder.cliOptions(catalog: [hiddenModel], states: states)

            #expect(options.count == 1)
            #expect(options.first?.id == "--model")
            #expect(options.first?.isEnabled == true)
            #expect(options.first?.value == "\(harness.rawValue)-model")
            #expect(options.first?.showOnPaneCreate == true)
        }
    }

    @Test("hidden OpenCode environment values are preserved")
    func hiddenOpenCodeEnvironmentValuesArePreserved() {
        guard var environment = EnvVarConfig.opencodeAll.first(where: { $0.id == "OPENCODE_CLIENT" }) else {
            Issue.record("Missing OpenCode environment catalog entry")
            return
        }
        environment.isAvailable = false

        let states = [
            environment.id: ProfileOptionDraft(
                enabled: true,
                value: "profile-client",
                showOnPaneCreate: true
            )
        ]
        let environmentValues = ProfileSnapshotBuilder.environmentVariables(
            catalog: [environment],
            states: states
        )

        #expect(environmentValues.count == 1)
        #expect(environmentValues.first?.id == "OPENCODE_CLIENT")
        #expect(environmentValues.first?.isEnabled == true)
        #expect(environmentValues.first?.value == "profile-client")
        #expect(environmentValues.first?.showOnPaneCreate == true)
    }
}
