import SwiftUI

struct PaneSettingsSnapshot {
    let paneName: String
    let harness: Harness
    let workingDirectory: String
    let shell: String
    let processStateDescription: String
    let worktreeIsManaged: Bool
    let profileName: String?
    let profileMissing: Bool
    let configuredArgs: [String]
    let fullCommand: [String]?
    let environmentVariables: [(key: String, value: String)]
    let opencodePort: Int?
    let opencodeSessionID: String?
}

enum PaneSettingsSheet {
    static func buildSnapshot(
        paneName: String,
        harness: Harness,
        extraArgs: [String],
        extraEnvVars: [String: String],
        workingDirectory: String?,
        worktreeIsManaged: Bool,
        shell: String?,
        fullCommand: [String]?,
        processStateDescription: String,
        profileID: UUID?,
        profiles: [Profile],
        opencodePort: Int?,
        opencodeSessionID: String?
    ) -> PaneSettingsSnapshot {
        let profileName: String?
        let profileMissing: Bool
        if let profileID {
            let profile = profiles.first { $0.id == profileID }
            profileName = profile?.name
            profileMissing = profile == nil
        } else {
            profileName = nil
            profileMissing = false
        }

        return PaneSettingsSnapshot(
            paneName: paneName,
            harness: harness,
            workingDirectory: workingDirectory ?? "\u{2014}",
            shell: shell ?? "$SHELL",
            processStateDescription: processStateDescription,
            worktreeIsManaged: worktreeIsManaged,
            profileName: profileName,
            profileMissing: profileMissing,
            configuredArgs: extraArgs,
            fullCommand: fullCommand,
            environmentVariables: extraEnvVars.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) },
            opencodePort: opencodePort,
            opencodeSessionID: opencodeSessionID
        )
    }
}

extension Pane {
    func settingsSnapshot(profiles: [Profile]) -> PaneSettingsSnapshot {
        let processStateDescription: String
        switch terminalController?.processState {
        case .none, .some(.idle):
            processStateDescription = "Idle"
        case .some(.running(let pid)):
            processStateDescription = "Running (pid \(pid))"
        case .some(.exited(let code)):
            processStateDescription = code.map { "Exited (code \($0))" } ?? "Exited"
        }
        return PaneSettingsSheet.buildSnapshot(
            paneName: name,
            harness: harness,
            extraArgs: extraArgs,
            extraEnvVars: extraEnvVars,
            workingDirectory: terminalController?.pendingDirectory ?? worktreeDirectory?.path ?? tab?.directory.path,
            worktreeIsManaged: worktreeIsManaged,
            shell: terminalController?.pendingShell,
            fullCommand: terminalController?.pendingCommandArgs,
            processStateDescription: processStateDescription,
            profileID: profileID,
            profiles: profiles,
            opencodePort: opencodePort,
            opencodeSessionID: opencodeSessionID
        )
    }
}

struct PaneSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: PaneSettingsSnapshot

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Pane", value: snapshot.paneName)
                LabeledContent("Harness", value: snapshot.harness.displayName)
                LabeledContent("Working Directory", value: snapshot.workingDirectory)
                LabeledContent("Shell", value: snapshot.shell)
                LabeledContent("Status", value: snapshot.processStateDescription)
            }

            if snapshot.profileName != nil || snapshot.profileMissing {
                Section("Profile") {
                    if snapshot.profileMissing {
                        Text("Profile no longer exists.")
                            .foregroundStyle(.secondary)
                    } else if let profileName = snapshot.profileName {
                        LabeledContent("Profile", value: profileName)
                    }
                }
            }

            Section("Configured CLI Options") {
                if snapshot.configuredArgs.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(snapshot.configuredArgs.enumerated()), id: \.offset) { _, arg in
                        Text(arg)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }

            Section("Environment Variables") {
                if snapshot.environmentVariables.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.environmentVariables, id: \.key) { entry in
                        Text("\(entry.key)=\(entry.value)")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }

            Section("Full Launch Command") {
                if let fullCommand = snapshot.fullCommand {
                    Text(fullCommand.joined(separator: " "))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text("Interactive shell (no harness command)")
                        .foregroundStyle(.secondary)
                }
            }

            if snapshot.harness == .opencode {
                Section("OpenCode") {
                    LabeledContent("Port", value: snapshot.opencodePort.map(String.init) ?? "\u{2014}")
                    LabeledContent("Session ID", value: snapshot.opencodeSessionID ?? "\u{2014}")
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("pane-settings-close-button")
                }
            }
        }
        .formStyle(.grouped)
        .pinnedFormBackground()
        .frame(width: 480)
        .accessibilityIdentifier("pane-settings-sheet")
    }
}
