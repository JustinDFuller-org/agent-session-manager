import SwiftUI

struct NewPaneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    let tab: Tab

    @State private var worktreeName = ""
    @State private var existingRef = ""
    @State private var openExistingBranchOrWorktree = false
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

    private var canSubmit: Bool {
        if activeToolList.isEmpty || isCreating { return false }
        if selectedCLIType == .claude, openExistingBranchOrWorktree {
            return !existingRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !worktreeName.isEmpty && nameError == nil
    }

    private var worktreePathPreview: String {
        "\(tab.directory.lastPathComponent)/\(Tab.worktreesRootRelativePath)/\(worktreeName.isEmpty ? "<name>" : worktreeName)"
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
                    .onChange(of: selectedCLIType) { _, newType in
                        initializeOptionStates()
                        if newType != .claude {
                            openExistingBranchOrWorktree = false
                            existingRef = ""
                            worktreeSetupError = nil
                        }
                    }
                }
            }

            if selectedCLIType == .claude, !openExistingBranchOrWorktree {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("auth-refactor, fix-login-bug, etc.", text: $worktreeName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { create() }
                        .accessibilityIdentifier("new-pane-name-field")
                    Text("Will open at \(worktreePathPreview)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .font(.system(.caption, design: .monospaced))
                    if let error = nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("new-pane-name-error")
                    }
                }
            }

            if selectedCLIType == .codex {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("auth-refactor, fix-login-bug, etc.", text: $worktreeName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { create() }
                        .accessibilityIdentifier("new-pane-name-field")
                    Text("Will open in \(tab.directory.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .font(.system(.caption, design: .monospaced))
                    if let error = nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("new-pane-name-error")
                    }
                }
            }

            if selectedCLIType == .claude {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Existing branch or worktree", isOn: $openExistingBranchOrWorktree)
                        .accessibilityIdentifier("new-pane-existing-worktree-toggle")
                        .onChange(of: openExistingBranchOrWorktree) { _, isOn in
                            if !isOn {
                                existingRef = ""
                                worktreeSetupError = nil
                            }
                        }
                    Text(
                        "When on, enter a branch, remote ref, or worktree folder name under .agent-session-manager/worktrees. The app reuses an existing linked worktree or runs git worktree add when needed."
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                    if openExistingBranchOrWorktree {
                        Text("Branch, ref, or worktree name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("main, origin/feature, my-worktree, …", text: $existingRef)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { create() }
                            .accessibilityIdentifier("new-pane-existing-ref-field")
                    }

                    if let error = worktreeSetupError {
                        ScrollView {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.leading)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 140)
                        .accessibilityIdentifier("new-pane-worktree-error")
                    }
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
                    .disabled(!canSubmit)
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
        guard canSubmit else { return }
        let extraArgs = buildExtraArgs()

        if selectedCLIType == .claude, openExistingBranchOrWorktree {
            let ref = existingRef.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ref.isEmpty else { return }
            isCreating = true
            worktreeSetupError = nil
            Task {
                do {
                    let resolved = try await tab.resolveOrAttachWorktree(userRef: ref)
                    await MainActor.run {
                        if appState.isWorktreeDuplicate(directory: tab.directory, name: resolved) {
                            isCreating = false
                            worktreeSetupError = "A pane with this worktree is already open."
                            return
                        }
                        resetForm()
                        tab.addPane(name: resolved, extraArgs: extraArgs, cliType: selectedCLIType)
                        appState.setActivePane(id: tab.panes.last?.id)
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isCreating = false
                        if let wre = error as? WorktreeResolutionError {
                            worktreeSetupError = wre.localizedDescription
                        } else if let gitErr = error as? GitCommandError {
                            worktreeSetupError = gitErr.localizedDescription
                        } else {
                            worktreeSetupError =
                                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        }
                    }
                }
            }
            return
        }

        guard !worktreeName.isEmpty, nameError == nil else { return }
        resetForm()
        tab.addPane(name: worktreeName, extraArgs: extraArgs, cliType: selectedCLIType)
        appState.setActivePane(id: tab.panes.last?.id)
        dismiss()
    }

    private func resetForm() {
        worktreeName = ""
        existingRef = ""
        openExistingBranchOrWorktree = false
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
