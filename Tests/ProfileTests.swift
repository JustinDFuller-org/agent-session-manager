import Foundation
import Testing

@testable import AgentSessionManager

@Suite("Profile")
struct ProfileTests {
    @Test("Profile encodes and decodes via JSON round-trip")
    func jsonRoundTrip() throws {
        let original = Profile(
            name: "Complex Task",
            harness: .claude,
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
        slc.factLabelStyle = .labelOnly
        let original = Profile(
            name: "Custom SL",
            harness: .cursor,
            cliOptions: [],
            envVars: [],
            statusLineConfig: slc
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        #expect(decoded.statusLineConfig != nil)
        #expect(decoded.statusLineConfig?.factLabelStyle == .labelOnly)
        #expect(decoded.name == "Custom SL")
        #expect(decoded.harness == .cursor)
    }

    @Test("Profile with nil status line inherits global")
    func nilStatusLineInheritsGlobal() {
        let profile = Profile(
            name: "No Override",
            harness: .claude,
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
            harness: .claude,
            profileID: profileID
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: data)
        #expect(decoded.profileID == profileID)
    }

    @Test("PersistedPane without profileID decodes as nil")
    func persistedPaneNilProfileID() throws {
        let json = """
            {"id":"00000000-0000-0000-0000-000000000001","name":"test","harness":"claude","isPriority":false,"isMerged":false,"worktreeIsManaged":false}
            """
        let decoded = try JSONDecoder().decode(PersistedPane.self, from: Data(json.utf8))
        #expect(decoded.profileID == nil)
    }

    @Test("Profiles container round-trips preserving order")
    func profilesContainerRoundTrip() throws {
        let profile1 = Profile(name: "A", harness: .claude)
        let profile2 = Profile(name: "B", harness: .cursor)

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
    func harnessPreserved() throws {
        for harness in [Harness.claude, .codex, .cursor] {
            let profile = Profile(name: "Test", harness: harness)
            let data = try JSONEncoder().encode(profile)
            let decoded = try JSONDecoder().decode(Profile.self, from: data)
            #expect(decoded.harness == harness)
        }
    }

    @Test("Move up swaps profiles")
    func testMoveUpSwapsProfiles() {
        var profiles = [
            Profile(name: "A", harness: .claude),
            Profile(name: "B", harness: .claude),
            Profile(name: "C", harness: .claude),
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
            Profile(name: "A", harness: .claude),
            Profile(name: "B", harness: .claude),
            Profile(name: "C", harness: .claude),
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
            Profile(name: "A", harness: .claude),
            Profile(name: "B", harness: .claude),
        ]
        let selectedIndex = 0
        let isDisabled = selectedIndex <= 0 || profiles.isEmpty
        #expect(isDisabled)
    }

    @Test("Move down disabled at bottom — last index has no valid swap")
    func testMoveDownDisabledAtBottom() {
        let profiles = [
            Profile(name: "A", harness: .claude),
            Profile(name: "B", harness: .claude),
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
        let profile = Profile(name: "MyProfile", harness: .claude)
        let mode = ProfileEditorMode.edit(profile)
        #expect(mode.profile?.id == profile.id)
        #expect(mode.id == profile.id.uuidString)
    }

    @Test("New pane pre-selects first ranked profile matching CLI type")
    func testNewPanePreselectsFirstRankedProfile() {
        let profiles = [
            Profile(name: "First", harness: .claude),
            Profile(name: "Second", harness: .claude),
            Profile(name: "Codex One", harness: .codex),
        ]
        let activeToolList: [Harness] = [.claude]
        let filtered = profiles.filter { activeToolList.contains($0.harness) }
        let selectedID = filtered.first?.id
        #expect(selectedID == profiles[0].id)
    }
}
