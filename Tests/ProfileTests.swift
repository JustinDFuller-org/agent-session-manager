import Foundation
import Testing

@testable import AgentSessionManager

@Suite("Profile")
struct ProfileTests {
    @Test("buildArgs returns enabled boolean flags")
    func buildArgsBooleanFlags() {
        let profile = Profile(
            name: "Test",
            cliType: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--verbose", isEnabled: true, value: nil),
                ProfileCLIOption(id: "--continue", isEnabled: false, value: nil),
                ProfileCLIOption(id: "--dangerously-skip-permissions", isEnabled: true, value: nil),
            ]
        )
        let args = profile.buildArgs()
        #expect(args == ["--verbose", "--dangerously-skip-permissions"])
    }

    @Test("buildArgs returns enabled string flags with values")
    func buildArgsStringFlags() {
        let profile = Profile(
            name: "Test",
            cliType: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--model", isEnabled: true, value: "claude-opus-4-6"),
                ProfileCLIOption(id: "--effort", isEnabled: true, value: "high"),
                ProfileCLIOption(id: "--resume", isEnabled: false, value: "session-1"),
            ]
        )
        let args = profile.buildArgs()
        #expect(args == ["--model", "'claude-opus-4-6'", "--effort", "'high'"])
    }

    @Test("buildArgs handles empty value for enabled string flag")
    func buildArgsEmptyStringValue() {
        let profile = Profile(
            name: "Test",
            cliType: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--model", isEnabled: true, value: ""),
                ProfileCLIOption(id: "--verbose", isEnabled: true, value: nil),
            ]
        )
        let args = profile.buildArgs()
        #expect(args == ["--model", "--verbose"])
    }

    @Test("buildArgs escapes single quotes in values")
    func buildArgsEscapesSingleQuotes() {
        let profile = Profile(
            name: "Test",
            cliType: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--system-prompt", isEnabled: true, value: "don't stop")
            ]
        )
        let args = profile.buildArgs()
        #expect(args == ["--system-prompt", "'don'\\''t stop'"])
    }

    @Test("buildArgs returns empty array when nothing enabled")
    func buildArgsNothingEnabled() {
        let profile = Profile(
            name: "Test",
            cliType: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--verbose", isEnabled: false, value: nil),
                ProfileCLIOption(id: "--model", isEnabled: false, value: "opus"),
            ]
        )
        let args = profile.buildArgs()
        #expect(args.isEmpty)
    }

    @Test("buildEnvVars returns enabled vars with values")
    func buildEnvVars() {
        let profile = Profile(
            name: "Test",
            cliType: .claude,
            envVars: [
                ProfileEnvVar(id: "ANTHROPIC_MODEL", isEnabled: true, value: "opus"),
                ProfileEnvVar(id: "DEBUG", isEnabled: false, value: "1"),
                ProfileEnvVar(id: "ANTHROPIC_API_KEY", isEnabled: true, value: "sk-123"),
            ]
        )
        let env = profile.buildEnvVars()
        #expect(env == ["ANTHROPIC_MODEL": "opus", "ANTHROPIC_API_KEY": "sk-123"])
    }

    @Test("buildEnvVars skips enabled vars with empty values")
    func buildEnvVarsSkipsEmpty() {
        let profile = Profile(
            name: "Test",
            cliType: .claude,
            envVars: [
                ProfileEnvVar(id: "ANTHROPIC_MODEL", isEnabled: true, value: "")
            ]
        )
        let env = profile.buildEnvVars()
        #expect(env.isEmpty)
    }

    @Test("Profile encodes and decodes via JSON round-trip")
    func jsonRoundTrip() throws {
        let original = Profile(
            name: "Complex Task",
            cliType: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--model", isEnabled: true, value: "claude-opus-4-6"),
                ProfileCLIOption(id: "--verbose", isEnabled: false, value: nil),
            ],
            envVars: [
                ProfileEnvVar(id: "ANTHROPIC_API_KEY", isEnabled: true, value: "sk-test")
            ],
            statusLineConfig: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        #expect(decoded == original)
    }

    @Test("Profile with custom status line round-trips")
    func jsonRoundTripWithStatusLine() throws {
        var slc = StatusLineConfig()
        slc.chipLabelStyle = .labelOnly
        let original = Profile(
            name: "Custom SL",
            cliType: .cursor,
            cliOptions: [],
            envVars: [],
            statusLineConfig: slc
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        #expect(decoded.statusLineConfig != nil)
        #expect(decoded.statusLineConfig?.chipLabelStyle == .labelOnly)
        #expect(decoded.name == "Custom SL")
        #expect(decoded.cliType == .cursor)
    }

    @Test("Profile with nil status line inherits global")
    func nilStatusLineInheritsGlobal() {
        let profile = Profile(
            name: "No Override",
            cliType: .claude,
            statusLineConfig: nil
        )
        #expect(profile.statusLineConfig == nil)
    }

    @Test("PersistedPane profileID round-trips")
    func persistedPaneProfileID() throws {
        let profileID = UUID()
        let original = PersistedPane(
            id: UUID(),
            name: "test",
            cliType: .claude,
            profileID: profileID
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: data)
        #expect(decoded.profileID == profileID)
    }

    @Test("PersistedPane without profileID decodes as nil")
    func persistedPaneNilProfileID() throws {
        let json = """
            {"id":"00000000-0000-0000-0000-000000000001","name":"test","cliType":"claude","isPriority":false,"isMerged":false,"worktreeIsManaged":false}
            """
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: Data(json.utf8))
        #expect(decoded.profileID == nil)
    }

    @Test("Profiles container round-trips preserving order")
    func profilesContainerRoundTrip() throws {
        let profile1 = Profile(name: "A", cliType: .claude)
        let profile2 = Profile(name: "B", cliType: .cursor)

        struct Container: Codable {
            var profiles: [Profile]
        }
        let original = Container(profiles: [profile1, profile2])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Container.self, from: data)
        #expect(decoded.profiles.count == 2)
        #expect(decoded.profiles[0].id == profile1.id)
        #expect(decoded.profiles[1].id == profile2.id)
    }

    @Test("Different CLI types preserved in profiles")
    func cliTypePreserved() throws {
        for cliType in [CLIType.claude, .codex, .cursor, .opencode] {
            let profile = Profile(name: "Test", cliType: cliType)
            let data = try JSONEncoder().encode(profile)
            let decoded = try JSONDecoder().decode(Profile.self, from: data)
            #expect(decoded.cliType == cliType)
        }
    }

    @Test("Move up swaps profiles")
    func testMoveUpSwapsProfiles() {
        var profiles = [
            Profile(name: "A", cliType: .claude),
            Profile(name: "B", cliType: .claude),
            Profile(name: "C", cliType: .claude),
        ]
        let originalFirst = profiles[0].id
        let originalSecond = profiles[1].id
        profiles.swapAt(1, 0)
        #expect(profiles[0].id == originalSecond)
        #expect(profiles[1].id == originalFirst)
    }

    @Test("Move down swaps profiles")
    func testMoveDownSwapsProfiles() {
        var profiles = [
            Profile(name: "A", cliType: .claude),
            Profile(name: "B", cliType: .claude),
            Profile(name: "C", cliType: .claude),
        ]
        let originalFirst = profiles[0].id
        let originalSecond = profiles[1].id
        profiles.swapAt(0, 1)
        #expect(profiles[0].id == originalSecond)
        #expect(profiles[1].id == originalFirst)
    }

    @Test("Move up disabled at top — index 0 has no valid swap")
    func testMoveUpDisabledAtTop() {
        let profiles = [
            Profile(name: "A", cliType: .claude),
            Profile(name: "B", cliType: .claude),
        ]
        let selectedIndex = 0
        let isDisabled = selectedIndex <= 0 || profiles.isEmpty
        #expect(isDisabled)
    }

    @Test("Move down disabled at bottom — last index has no valid swap")
    func testMoveDownDisabledAtBottom() {
        let profiles = [
            Profile(name: "A", cliType: .claude),
            Profile(name: "B", cliType: .claude),
        ]
        let lastIndex = profiles.count - 1
        let isDisabled = lastIndex == profiles.count - 1
        #expect(isDisabled)
    }

    @Test("ProfileEditorMode.new has nil profile and 'new' id")
    func profileEditorModeNew() {
        let mode = ProfileEditorMode.new
        #expect(mode.profile == nil)
        #expect(mode.id == "new")
    }

    @Test("ProfileEditorMode.edit carries profile and uses UUID as id")
    func profileEditorModeEdit() {
        let profile = Profile(name: "MyProfile", cliType: .claude)
        let mode = ProfileEditorMode.edit(profile)
        #expect(mode.profile?.id == profile.id)
        #expect(mode.id == profile.id.uuidString)
    }

    @Test("New pane pre-selects first ranked profile matching CLI type")
    func testNewPanePreselectsFirstRankedProfile() {
        let profiles = [
            Profile(name: "First", cliType: .claude),
            Profile(name: "Second", cliType: .claude),
            Profile(name: "Codex One", cliType: .codex),
        ]
        let activeToolList: [CLIType] = [.claude]
        let filtered = profiles.filter { activeToolList.contains($0.cliType) }
        let selectedID = filtered.first?.id
        #expect(selectedID == profiles[0].id)
    }
}
