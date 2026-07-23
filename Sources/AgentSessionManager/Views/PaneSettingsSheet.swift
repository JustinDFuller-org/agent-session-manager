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
    struct Input {
        let paneName: String
        let harness: Harness
        let extraArgs: [String]
        let extraEnvVars: [String: String]
        let workingDirectory: String?
        let worktreeIsManaged: Bool
        let shell: String?
        let fullCommand: [String]?
        let processStateDescription: String
        let profileID: UUID?
        let opencodePort: Int?
        let opencodeSessionID: String?
    }

    static func buildSnapshot(_ input: Input, profiles: [Profile]) -> PaneSettingsSnapshot {
        let profileName: String?
        let profileMissing: Bool
        if let profileID = input.profileID {
            let profile = profiles.first { $0.id == profileID }
            profileName = profile?.name
            profileMissing = profile == nil
        } else {
            profileName = nil
            profileMissing = false
        }

        return PaneSettingsSnapshot(
            paneName: input.paneName,
            harness: input.harness,
            workingDirectory: input.workingDirectory ?? "\u{2014}",
            shell: input.shell ?? "$SHELL",
            processStateDescription: input.processStateDescription,
            worktreeIsManaged: input.worktreeIsManaged,
            profileName: profileName,
            profileMissing: profileMissing,
            configuredArgs: input.extraArgs,
            fullCommand: input.fullCommand,
            environmentVariables: input.extraEnvVars.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) },
            opencodePort: input.opencodePort,
            opencodeSessionID: input.opencodeSessionID
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
            .init(
                paneName: name,
                harness: harness,
                extraArgs: extraArgs,
                extraEnvVars: extraEnvVars,
                workingDirectory: terminalController?.pendingDirectory ?? worktreeDirectory?.path
                    ?? tab?.directory.path,
                worktreeIsManaged: worktreeIsManaged,
                shell: terminalController?.pendingShell,
                fullCommand: terminalController?.pendingCommandArgs,
                processStateDescription: processStateDescription,
                profileID: profileID,
                opencodePort: opencodePort,
                opencodeSessionID: opencodeSessionID
            ),
            profiles: profiles
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
