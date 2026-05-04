import SwiftUI

struct NewPaneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    let tab: Tab

    @State private var worktreeName = ""
    @State private var branchName = ""
    @State private var worktreeNameEdited = false
    @State private var selectedCLIType: CLIType = .claude
    @State private var optionStates: [String: OptionState] = [:]
    @State private var isCreating = false
    @State private var worktreeSetupError: String?

    private var activeToolList: [CLIType] {
        CLIType.allCases.filter { appSettings.isActive($0) }
    }

    private var activeOptions: [CLIOptionConfig] {
        switch selectedCLIType {
        case .claude: return appSettings.cliOptions
        case .codex: return appSettings.codexCliOptions
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Pane")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("CLI")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if activeToolList.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                        (Text("No tools are active. Enable a tool in ")
                            .foregroundStyle(.secondary)
                        + Text("Settings \u{2192} Tools")
                            .foregroundColor(.accentColor))
                    }
                    .font(.subheadline)
                } else {
                    Picker("CLI", selection: $selectedCLIType) {
                        ForEach(activeToolList, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: selectedCLIType) { initializeOptionStates() }
                }
            }

            if selectedCLIType == .claude {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Branch (optional)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("dependabot/go_modules/...", text: $branchName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { create() }
                        .onChange(of: branchName) { _, newValue in
                            if !worktreeNameEdited {
                                worktreeName = newValue.isEmpty ? "" : Tab.sanitizeBranchName(newValue)
                            }
                        }
                    Text("Leave empty to create a new worktree from HEAD")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if let error = worktreeSetupError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Session Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("auth-refactor, fix-login-bug, etc.", text: $worktreeName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { create() }
                    .onChange(of: worktreeName) { _, _ in
                        worktreeNameEdited = !branchName.isEmpty
                    }
                    .accessibilityIdentifier("new-pane-name-field")
                if selectedCLIType == .claude {
                    Text("Will open at \(tab.directory.lastPathComponent)/.tree/\(worktreeName.isEmpty ? "<name>" : worktreeName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .font(.system(.caption, design: .monospaced))
                } else {
                    Text("Will open in \(tab.directory.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .font(.system(.caption, design: .monospaced))
                }
                if let error = nameError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("new-pane-name-error")
                }
            }

            let available = activeOptions.filter(\.isAvailable)
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
                    .disabled(worktreeName.isEmpty || nameError != nil || activeToolList.isEmpty || isCreating)
                    .accessibilityIdentifier("new-pane-open-button")
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            if !activeToolList.contains(selectedCLIType) {
                selectedCLIType = activeToolList.first ?? .claude
            }
            initializeOptionStates()
        }
    }

    private var nameError: String? {
        guard !worktreeName.isEmpty else { return nil }
        if !Tab.isValidWorktreeName(worktreeName) {
            return "Name may only contain letters, digits, dots, underscores, and dashes."
        }
        if appState.isWorktreeDuplicate(directory: tab.directory, name: worktreeName) {
            return "A pane with this worktree is already open."
        }
        return nil
    }

    private func stateBinding(for option: CLIOptionConfig) -> Binding<OptionState> {
        Binding(
            get: { optionStates[option.id] ?? OptionState(enabled: option.isDefaultEnabled, value: "") },
            set: { optionStates[option.id] = $0 }
        )
    }

    private func initializeOptionStates() {
        optionStates = [:]
        for option in activeOptions where option.isAvailable {
            optionStates[option.id] = OptionState(enabled: option.isDefaultEnabled, value: "")
        }
    }

    private func create() {
        guard !worktreeName.isEmpty, nameError == nil else { return }
        let extraArgs = buildExtraArgs()
        let name = worktreeName
        let branch = branchName.isEmpty ? nil : branchName

        guard let branch else {
            resetForm()
            tab.addPane(name: name, extraArgs: extraArgs, cliType: selectedCLIType)
            appState.setActivePane(id: tab.panes.last?.id)
            dismiss()
            return
        }

        isCreating = true
        worktreeSetupError = nil
        Task {
            do {
                try await tab.setupWorktree(name: name, branchName: branch, defaultBranch: appSettings.defaultBranch)
                await MainActor.run {
                    resetForm()
                    tab.addPane(name: name, extraArgs: extraArgs, cliType: selectedCLIType)
                    appState.setActivePane(id: tab.panes.last?.id)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    worktreeSetupError = "Failed to set up worktree for branch '\(branch)'. Check that the branch exists locally or on origin."
                }
            }
        }
    }

    private func resetForm() {
        worktreeName = ""
        branchName = ""
        worktreeNameEdited = false
        worktreeSetupError = nil
        isCreating = false
    }

    private func buildExtraArgs() -> [String] {
        var args: [String] = []
        for option in activeOptions where option.isAvailable {
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
