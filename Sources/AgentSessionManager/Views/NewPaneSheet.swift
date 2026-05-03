import SwiftUI

struct NewPaneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var appSettings
    let tab: Tab

    @State private var worktreeName = ""
    @State private var optionStates: [String: OptionState] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Pane")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Worktree / Branch Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("auth-refactor, fix-login-bug, etc.", text: $worktreeName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { create() }
                    .accessibilityIdentifier("new-pane-name-field")
                Text("Will open at \(tab.directory.lastPathComponent)/.tree/\(worktreeName.isEmpty ? "<name>" : worktreeName)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .font(.system(.caption, design: .monospaced))
            }

            let available = appSettings.cliOptions.filter(\.isAvailable)
            if !available.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CLI Options")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(available) { option in
                            CLIOptionToggleRow(option: option, state: stateBinding(for: option))
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("new-pane-cancel-button")
                Button("Open") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(worktreeName.isEmpty)
                    .accessibilityIdentifier("new-pane-open-button")
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear { initializeOptionStates() }
    }

    private func stateBinding(for option: CLIOptionConfig) -> Binding<OptionState> {
        Binding(
            get: { optionStates[option.id] ?? OptionState(enabled: option.isDefaultEnabled, value: "") },
            set: { optionStates[option.id] = $0 }
        )
    }

    private func initializeOptionStates() {
        for option in appSettings.cliOptions where option.isAvailable {
            optionStates[option.id] = OptionState(enabled: option.isDefaultEnabled, value: "")
        }
    }

    private func create() {
        guard !worktreeName.isEmpty else { return }
        let extraArgs = buildExtraArgs()
        tab.addPane(name: worktreeName, extraArgs: extraArgs)
        dismiss()
    }

    private func buildExtraArgs() -> [String] {
        var args: [String] = []
        for option in appSettings.cliOptions where option.isAvailable {
            guard let state = optionStates[option.id], state.enabled else { continue }
            switch option.optionType {
            case .boolean:
                args.append(option.id)
            case .string:
                let value = state.value.trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
                    args.append(contentsOf: [option.id, "'\(escaped)'"])
                } else {
                    args.append(option.id)
                }
            }
        }
        return args
    }
}

private struct OptionState {
    var enabled: Bool
    var value: String
}

private struct CLIOptionToggleRow: View {
    let option: CLIOptionConfig
    @Binding var state: OptionState

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle(isOn: $state.enabled) {
                Text(option.id)
                    .font(.system(.body, design: .monospaced))
                    .font(.caption)
            }
            if case let .string(placeholder) = option.optionType {
                TextField(placeholder, text: $state.value)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!state.enabled)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
