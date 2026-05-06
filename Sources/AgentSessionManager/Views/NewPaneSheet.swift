import SwiftUI

struct NewPaneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    let tab: Tab

    /// Session name shared across tools; for Claude also accepts branch ref or existing worktree name.
    @State private var sessionInput = ""
    @State private var selectedCLIType: CLIType = .claude
    @State private var optionStates: [String: OptionState] = [:]
    @State private var isCreating = false
    @State private var isClassifyingIntent = false
    @State private var worktreeSetupError: String?
    @State private var isPriority = false
    /// Reuse confirmation (Claude existing checkout).
    @State private var reuseConfirmPresented = false
    @State private var reuseConfirmationMessage = ""
    @State private var reuseRawRefForConfirm = ""

    private var activeToolList: [CLIType] {
        CLIType.allCases.filter { appSettings.isActive($0) }
    }

    private var activeOptions: [CLIOptionConfig] {
        switch selectedCLIType {
        case .claude: return appSettings.cliOptions
        case .codex: return appSettings.codexCliOptions
        case .cursor: return appSettings.cursorCliOptions
        }
    }

    private var trimmedClaudeInput: String {
        sessionInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCodexInput: String {
        sessionInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isBusy: Bool {
        isCreating || isClassifyingIntent
    }

    private var claudeValidationError: String? {
        let t = trimmedClaudeInput
        guard !t.isEmpty else { return nil }
        if t.contains("/") || t.hasPrefix("refs/") {
            return nil
        }
        if !Tab.isValidWorktreeName(t) {
            return "Name may only contain letters, digits, dots, underscores, and dashes. For a branch, use a ref such as origin/feature."
        }
        if appState.isWorktreeDuplicate(directory: tab.directory, name: t) {
            return "A pane with this worktree is already open."
        }
        return nil
    }

    private var codexNameError: String? {
        let t = trimmedCodexInput
        guard !t.isEmpty else { return nil }
        if !Tab.isValidWorktreeName(t) {
            return "Name may only contain letters, digits, dots, underscores, and dashes."
        }
        if appState.isWorktreeDuplicate(directory: tab.directory, name: t) {
            return "A pane with this worktree is already open."
        }
        return nil
    }

    private var canSubmit: Bool {
        guard !activeToolList.isEmpty, !isBusy else { return false }
        switch selectedCLIType {
        case .claude:
            return !trimmedClaudeInput.isEmpty && claudeValidationError == nil
        case .codex:
            return !trimmedCodexInput.isEmpty && codexNameError == nil
        case .cursor:
            return !trimmedCodexInput.isEmpty && codexNameError == nil
        }
    }

    private var worktreePathPreview: String {
        let name = trimmedClaudeInput.isEmpty ? "<name>" : trimmedClaudeInput
        return "\(tab.directory.lastPathComponent)/\(Tab.worktreesRootRelativePath)/\(name)"
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
                    .accessibilityIdentifier("new-pane-cli-picker")
                    .onChange(of: selectedCLIType) { _, _ in
                        initializeOptionStates()
                        worktreeSetupError = nil
                        reuseConfirmPresented = false
                    }
                }
            }

            if selectedCLIType == .claude {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session, branch, or worktree")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("auth-refactor, origin/feature, my-worktree, …", text: $sessionInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { create() }
                        .accessibilityIdentifier("new-pane-name-field")
                        .disabled(isBusy)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session name, branch ref, or worktree.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(worktreePathPreview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        if let validation = claudeValidationError {
                            Text(validation)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("new-pane-name-error")
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
                            .frame(maxHeight: 120)
                            .accessibilityIdentifier("new-pane-worktree-error")
                        }
                    }
                    .frame(minHeight: 120, alignment: .topLeading)
                }
            }

            if selectedCLIType == .codex {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("auth-refactor, fix-login-bug, etc.", text: $sessionInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { create() }
                        .accessibilityIdentifier("new-pane-name-field")
                    Text("Will open in \(tab.directory.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .font(.system(.caption, design: .monospaced))
                    if let error = codexNameError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("new-pane-name-error")
                    }
                }
                .frame(minHeight: 80, alignment: .topLeading)
            }

            if selectedCLIType == .cursor {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("auth-refactor, fix-login-bug, etc.", text: $sessionInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { create() }
                        .accessibilityIdentifier("new-pane-name-field")
                    Text("Will open in \(tab.directory.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .font(.system(.caption, design: .monospaced))
                    if let error = codexNameError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("new-pane-name-error")
                    }
                }
                .frame(minHeight: 80, alignment: .topLeading)
            }

            if selectedCLIType == .claude && appSettings.isPriorityNotificationsEnabled {
                Toggle(isOn: $isPriority) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Priority Pane")
                            .font(.subheadline)
                        Text("Priority notifications jump to the top of the sidebar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("new-pane-priority-toggle")
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
        .confirmationDialog(
            "Reuse checkout",
            isPresented: $reuseConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Continue") {
                runResolveAttached(rawRef: reuseRawRefForConfirm)
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("new-pane-reuse-confirm-continue")
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("new-pane-reuse-confirm-cancel")
        } message: {
            Text(reuseConfirmationMessage)
        }
        .onAppear {
            if !activeToolList.contains(selectedCLIType) {
                selectedCLIType = activeToolList.first ?? .claude
            }
            initializeOptionStates()
        }
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
        switch selectedCLIType {
        case .codex:
            guard !trimmedCodexInput.isEmpty, codexNameError == nil else { return }
            let extraArgs = buildExtraArgs()
            resetForm()
            tab.addPane(name: trimmedCodexInput, extraArgs: extraArgs, cliType: .codex)
            appState.setActivePane(id: tab.panes.last?.id)
            SessionPersistence.save(appState: appState)
            dismiss()
            return

        case .cursor:
            guard !trimmedCodexInput.isEmpty, codexNameError == nil else { return }
            let extraArgs = buildExtraArgs()
            resetForm()
            tab.addPane(name: trimmedCodexInput, extraArgs: extraArgs, cliType: .cursor)
            appState.setActivePane(id: tab.panes.last?.id)
            SessionPersistence.save(appState: appState)
            dismiss()
            return

        case .claude:
            let trimmed = trimmedClaudeInput
            guard !trimmed.isEmpty, claudeValidationError == nil else { return }
            isClassifyingIntent = true
            worktreeSetupError = nil

            Task {
                do {
                    let intent = try await tab.classifyClaudePaneIntent(userRef: trimmed)
                    await MainActor.run {
                        isClassifyingIntent = false

                        switch intent {
                        case let .reuse(confirmationMessage, rawInput, resolved):
                            if appState.isClaudeCheckoutInUse(directory: tab.directory, checkout: resolved.checkoutURL) {
                                worktreeSetupError = "A pane with this worktree is already open."
                                return
                            }
                            reuseConfirmationMessage = confirmationMessage
                            reuseRawRefForConfirm = rawInput
                            reuseConfirmPresented = true

                        case let .resolveViaApp(rawInput):
                            runResolveAttached(rawRef: rawInput)

                        case let .claudeWorktreeFlag(name):
                            let extraArgs = buildExtraArgs()
                            resetForm()
                            tab.addPane(name: name, extraArgs: extraArgs, cliType: .claude)
                            if let pane = tab.panes.last {
                                wireBell(pane: pane, priority: isPriority)
                            }
                            appState.setActivePane(id: tab.panes.last?.id)
                            SessionPersistence.save(appState: appState)
                            dismiss()
                        }
                    }
                } catch {
                    await MainActor.run {
                        isClassifyingIntent = false
                        applyResolveError(error)
                    }
                }
            }
            return
        }
    }

    private func applyResolveError(_ error: Error) {
        if let wre = error as? WorktreeResolutionError {
            worktreeSetupError = wre.localizedDescription
        } else if let gitErr = error as? GitCommandError {
            worktreeSetupError = gitErr.localizedDescription
        } else {
            worktreeSetupError =
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Runs Git attach/create then opens the pane (after confirmation or `.resolveViaApp`).
    private func runResolveAttached(rawRef: String) {
        guard !rawRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let extraArgs = buildExtraArgs()
        isCreating = true
        worktreeSetupError = nil
        Task {
            do {
                let resolved = try await tab.resolveOrAttachWorktree(userRef: rawRef)
                await MainActor.run {
                    if appState.isClaudeCheckoutInUse(directory: tab.directory, checkout: resolved.checkoutURL) {
                        isCreating = false
                        worktreeSetupError = "A pane with this worktree is already open."
                        return
                    }
                    resetForm()
                    tab.addPane(
                        name: resolved.paneTitle,
                        extraArgs: extraArgs,
                        cliType: .claude,
                        claudeDirectoryOverride: resolved.claudeProcessDirectory
                    )
                    if let pane = tab.panes.last {
                        wireBell(pane: pane, priority: isPriority)
                    }
                    appState.setActivePane(id: tab.panes.last?.id)
                    SessionPersistence.save(appState: appState)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    applyResolveError(error)
                }
            }
        }
    }

    private func wireBell(pane: Pane, priority: Bool) {
        pane.isPriority = priority
        pane.terminalController?.onBell = { [weak appState, weak tab, weak pane] in
            Task { @MainActor in
                guard let appState, let tab, let pane else { return }
                appState.addNotification(
                    paneID: pane.id,
                    paneName: pane.name,
                    tabID: tab.id,
                    tabName: tab.name,
                    isPriority: pane.isPriority
                )
            }
        }
    }

    private func resetForm() {
        sessionInput = ""
        worktreeSetupError = nil
        isCreating = false
        isClassifyingIntent = false
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
