import Foundation
import Testing

@testable import AgentSessionManager

@Suite("ProfileEditorHiddenOptions")
struct ProfileEditorHiddenOptionsTests {
    @Test("save includes hidden-but-enabled option in profile.cliOptions")
    func saveIncludesHiddenEnabledOption() throws {
        let profile = Profile(
            name: "Test",
            harness: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--continue", isEnabled: true, value: nil),
                ProfileCLIOption(id: "--verbose", isEnabled: true, value: nil),
            ]
        )
        let args = profile.buildArgs()
        #expect(args.contains("--continue"))
        #expect(args.contains("--verbose"))
    }

    @Test("save does not include hidden-but-disabled option")
    func saveExcludesHiddenDisabledOption() {
        let profile = Profile(
            name: "Test",
            harness: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--verbose", isEnabled: false, value: nil)
            ]
        )
        let args = profile.buildArgs()
        #expect(!args.contains("--verbose"))
    }

    @Test("save includes globally available options regardless of isAvailable flag in config")
    func saveIncludesGloballyAvailableOptions() {
        let profile = Profile(
            name: "Test",
            harness: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--continue", isEnabled: true, value: nil),
                ProfileCLIOption(id: "--model", isEnabled: true, value: "claude-sonnet-4-6"),
            ]
        )
        let args = profile.buildArgs()
        #expect(args.contains("--continue"))
        #expect(args.contains("--model"))
    }

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

    @Test("profile buildArgs includes hidden string option with value")
    func hiddenStringOptionWithValue() {
        let profile = Profile(
            name: "Test",
            harness: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--model", isEnabled: true, value: "claude-opus-4-8")
            ]
        )
        let args = profile.buildArgs()
        #expect(args.contains("--model"))
        #expect(args.contains("'claude-opus-4-8'"))
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

    @Test("profile buildEnvVars includes hidden-but-enabled env var")
    func hiddenEnvVarIncludedInBuild() {
        let profile = Profile(
            name: "Test",
            harness: .claude,
            cliOptions: [],
            envVars: [
                ProfileEnvVar(id: "ANTHROPIC_MODEL", isEnabled: true, value: "claude-opus-4-8"),
                ProfileEnvVar(id: "DEBUG", isEnabled: false, value: "1"),
            ]
        )
        let env = profile.buildEnvVars()
        #expect(env["ANTHROPIC_MODEL"] == "claude-opus-4-8")
        #expect(env["DEBUG"] == nil)
    }
}
