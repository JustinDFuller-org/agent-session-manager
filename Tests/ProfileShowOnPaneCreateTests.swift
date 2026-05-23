import Foundation
import Testing

@testable import AgentSessionManager

@Suite("ProfileShowOnPaneCreate")
struct ProfileShowOnPaneCreateTests {
    @Test("ProfileCLIOption decodes old JSON without showOnPaneCreate as false")
    func cliOptionBackwardCompatibleDecode() throws {
        let json = """
            {"id":"--model","isEnabled":true}
            """
        let decoded = try JSONDecoder().decode(ProfileCLIOption.self, from: Data(json.utf8))
        #expect(decoded.id == "--model")
        #expect(decoded.isEnabled == true)
        #expect(decoded.showOnPaneCreate == false)
    }

    @Test("ProfileCLIOption round-trips showOnPaneCreate true")
    func cliOptionRoundTrip() throws {
        let original = ProfileCLIOption(id: "--continue", isEnabled: true, value: nil, showOnPaneCreate: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProfileCLIOption.self, from: data)
        #expect(decoded.id == "--continue")
        #expect(decoded.showOnPaneCreate == true)
    }

    @Test("ProfileCLIOption round-trips showOnPaneCreate false")
    func cliOptionRoundTripFalse() throws {
        let original = ProfileCLIOption(
            id: "--model", isEnabled: true, value: "claude-opus-4-7", showOnPaneCreate: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProfileCLIOption.self, from: data)
        #expect(decoded.showOnPaneCreate == false)
    }

    @Test("ProfileEnvVar decodes old JSON without showOnPaneCreate as false")
    func envVarBackwardCompatibleDecode() throws {
        let json = """
            {"id":"ANTHROPIC_API_KEY","isEnabled":true,"value":"sk-test"}
            """
        let decoded = try JSONDecoder().decode(ProfileEnvVar.self, from: Data(json.utf8))
        #expect(decoded.id == "ANTHROPIC_API_KEY")
        #expect(decoded.showOnPaneCreate == false)
    }

    @Test("ProfileEnvVar round-trips showOnPaneCreate true")
    func envVarRoundTrip() throws {
        let original = ProfileEnvVar(id: "ANTHROPIC_API_KEY", isEnabled: true, value: "sk-test", showOnPaneCreate: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProfileEnvVar.self, from: data)
        #expect(decoded.showOnPaneCreate == true)
    }

    @Test("Profile.buildArgs includes hidden options (showOnPaneCreate false)")
    func buildArgsIncludesHiddenOptions() {
        let profile = Profile(
            name: "Test",
            cliType: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--model", isEnabled: true, value: "claude-opus-4-7", showOnPaneCreate: false),
                ProfileCLIOption(id: "--continue", isEnabled: true, value: nil, showOnPaneCreate: true),
            ]
        )
        let args = profile.buildArgs()
        #expect(args.contains("--model"))
        #expect(args.contains("--continue"))
    }

    @Test("Profile.buildArgs excludes disabled options regardless of showOnPaneCreate")
    func buildArgsExcludesDisabledOptions() {
        let profile = Profile(
            name: "Test",
            cliType: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--verbose", isEnabled: false, value: nil, showOnPaneCreate: true),
                ProfileCLIOption(id: "--model", isEnabled: false, value: "opus", showOnPaneCreate: false),
            ]
        )
        let args = profile.buildArgs()
        #expect(args.isEmpty)
    }

    @Test("ProfileCLIOption default showOnPaneCreate is false")
    func cliOptionDefaultShowOnPaneCreate() {
        let option = ProfileCLIOption(id: "--verbose", isEnabled: true)
        #expect(option.showOnPaneCreate == false)
    }

    @Test("ProfileEnvVar default showOnPaneCreate is false")
    func envVarDefaultShowOnPaneCreate() {
        let envVar = ProfileEnvVar(id: "ANTHROPIC_API_KEY", isEnabled: true, value: "sk-test")
        #expect(envVar.showOnPaneCreate == false)
    }
}
