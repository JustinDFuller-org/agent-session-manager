import Foundation
import Testing

@testable import AgentSessionManager

@Suite("PaneSettingsSnapshot")
struct PaneSettingsSnapshotTests {
    private func snapshot(
        extraArgs: [String] = [],
        extraEnvVars: [String: String] = [:],
        workingDirectory: String? = "/tmp/repo",
        worktreeIsManaged: Bool = false,
        shell: String? = "/bin/zsh",
        fullCommand: [String]? = ["claude", "--continue"],
        profileID: UUID? = nil,
        profiles: [Profile] = [],
        opencodePort: Int? = nil,
        opencodeSessionID: String? = nil
    ) -> PaneSettingsSnapshot {
        PaneSettingsSheet.buildSnapshot(
            paneName: "auth-refactor",
            harness: .claude,
            extraArgs: extraArgs,
            extraEnvVars: extraEnvVars,
            workingDirectory: workingDirectory,
            worktreeIsManaged: worktreeIsManaged,
            shell: shell,
            fullCommand: fullCommand,
            processStateDescription: "Running (pid 123)",
            profileID: profileID,
            profiles: profiles,
            opencodePort: opencodePort,
            opencodeSessionID: opencodeSessionID
        )
    }

    @Test("Environment variables come back sorted by key regardless of input order")
    func environmentVariablesAreSortedByKey() {
        let result = snapshot(extraEnvVars: ["ZEBRA": "1", "ALPHA": "2", "MID": "3"])
        #expect(result.environmentVariables.map(\.key) == ["ALPHA", "MID", "ZEBRA"])
    }

    @Test("A set profileID missing from the profiles list is reported as missing")
    func missingProfileIsReported() {
        let result = snapshot(profileID: UUID(), profiles: [])
        #expect(result.profileMissing == true)
        #expect(result.profileName == nil)
    }

    @Test("A nil profileID is not reported as missing")
    func nilProfileIsNotMissing() {
        let result = snapshot(profileID: nil, profiles: [])
        #expect(result.profileMissing == false)
        #expect(result.profileName == nil)
    }

    @Test("A profileID present in the profiles list resolves its name")
    func presentProfileResolvesName() {
        let profile = Profile(name: "Complex Task", harness: .claude)
        let result = snapshot(profileID: profile.id, profiles: [profile])
        #expect(result.profileMissing == false)
        #expect(result.profileName == "Complex Task")
    }

    @Test("A nil fullCommand is preserved rather than defaulted to an empty array")
    func nilFullCommandIsPreserved() {
        let result = snapshot(fullCommand: nil)
        #expect(result.fullCommand == nil)
    }

    @Test("A non-nil fullCommand passes through unchanged")
    func nonNilFullCommandPassesThrough() {
        let result = snapshot(fullCommand: ["claude", "--continue"])
        #expect(result.fullCommand == ["claude", "--continue"])
    }

    @Test("workingDirectory falls back to an em dash when nil")
    func workingDirectoryFallsBackWhenNil() {
        let result = snapshot(workingDirectory: nil)
        #expect(result.workingDirectory == "\u{2014}")
    }

    @Test("shell falls back to $SHELL when nil")
    func shellFallsBackWhenNil() {
        let result = snapshot(shell: nil)
        #expect(result.shell == "$SHELL")
    }

    @Test("OpenCode fields pass through only what's given")
    func opencodeFieldsPassThrough() {
        let result = snapshot(opencodePort: 4096, opencodeSessionID: "session-123")
        #expect(result.opencodePort == 4096)
        #expect(result.opencodeSessionID == "session-123")

        let empty = snapshot()
        #expect(empty.opencodePort == nil)
        #expect(empty.opencodeSessionID == nil)
    }
}
