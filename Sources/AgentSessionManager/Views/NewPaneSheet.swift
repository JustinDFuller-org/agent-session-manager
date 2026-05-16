import SwiftUI

struct NewPaneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    let tab: Tab
    var refreshingPane: Pane? = nil

    @State private var sessionInput = ""
    @State private var selectedCLIType: CLIType = .claude
    @State private var selectedProfileID: UUID?
    @State private var optionStates: [String: OptionState] = [:]
    @State private var envVarStates: [String: OptionState] = [:]
    @State private var isCreating = false
    @State private var worktreeSetupError: String?
    @State private var isPriority = false

    @State private var showTakeoverDialog = false
    @State private var pendingResolution: ResolvedWorktree?
    @State private var pendingExtraArgs: [String] = []
    @State private var pendingExtraEnvVars: [String: String] = [:]

    @State private var showSaveProfileSheet = false
    @State private var saveProfileName = ""

    @FocusState private var isSessionInputFocused: Bool

    private var activeToolList: [CLIType] {
        CLIType.allCases.filter { appSettings.isActive($0) }
    }

    private var activeOptions: [CLIOptionConfig] {
        switch selectedCLIType {
        case .claude: return appSettings.cliOptions
        case .codex: return appSettings.codexCliOptions
        case .cursor: return appSettings.cursorCliOptions
        case .opencode: return appSettings.opencodeCliOptions
        case .shell: return []
        }
    }

    private var trimmedInput: String {
        sessionInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isBusy: Bool {
        isCreating
    }

    private var isRefreshing: Bool { refreshingPane != nil }

    private var validationError: String? {
        let trimmed = trimmedInput
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("/") || trimmed.hasPrefix("refs/") {
            return nil
        }
        if !Tab.isValidWorktreeName(trimmed) {
            return
                "Name may only contain letters, digits, dots, underscores, and dashes. For a branch, use a ref such as origin/feature."
        }
        if !isRefreshing && appState.isWorktreeDuplicate(directory: tab.directory, name: trimmed) {
            return "A pane with this worktree is already open."
        }
        return nil
    }

    private var canSubmit: Bool {
        guard !activeToolList.isEmpty, !isBusy else { return false }
        return !trimmedInput.isEmpty && validationError == nil
    }

    private var worktreePathPreview: String {
        let name = trimmedInput.isEmpty ? "<name>" : trimmedInput
        return "\(tab.directory.lastPathComponent)/\(Tab.worktreesRootRelativePath)/\(name)"
    }

    private var selectedProfile: Profile? {
        guard let id = selectedProfileID else { return nil }
        return appSettings.profiles.first { $0.id == id }
    }

    private var isFormModifiedFromProfile: Bool {
        guard let profile = selectedProfile else { return true }
        if selectedCLIType != profile.cliType { return true }
        for opt in profile.cliOptions {
            let state = optionStates[opt.id]
            if state?.enabled != opt.isEnabled { return true }
            if let val = opt.value, state?.value != val { return true }
            if opt.value == nil && !(state?.value ?? "").isEmpty { return true }
        }
        for ev in profile.envVars {
            let state = envVarStates[ev.id]
            if state?.enabled != ev.isEnabled { return true }
            if state?.value != ev.value { return true }
        }
        return false
    }

    private var profilePickerLabel: String {
        if let profile = selectedProfile {
            return isFormModifiedFromProfile ? "\(profile.name) (modified)" : profile.name
        }
        return "Custom"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isRefreshing ? "Refresh Pane" : "New Pane")
                .font(.headline)

            if !isRefreshing {
                profilePickerSection
            }

            if selectedProfileID == nil {
                cliPickerSection
            }

            sessionNameSection

            if appSettings.isPriorityNotificationsEnabled {
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

            cliOptionsSection
            envVarSection

            actionButtons
        }
        .padding(24)
        .frame(width: 420)
        .confirmationDialog(
            "Manage existing worktree?",
            isPresented: $showTakeoverDialog,
            titleVisibility: .visible
        ) {
            Button("Manage") {
                guard let resolved = pendingResolution else { return }
                finishCreate(
                    resolved: resolved, managed: true, extraArgs: pendingExtraArgs,
                    extraEnvVars: pendingExtraEnvVars)
            }
            .accessibilityIdentifier("takeover-manage-button")
            Button("Don't Manage") {
                guard let resolved = pendingResolution else { return }
                finishCreate(
                    resolved: resolved, managed: false, extraArgs: pendingExtraArgs,
                    extraEnvVars: pendingExtraEnvVars)
            }
            .accessibilityIdentifier("takeover-dont-manage-button")
            Button("Cancel", role: .cancel) {
                pendingResolution = nil
                pendingExtraArgs = []
                pendingExtraEnvVars = [:]
            }
            .accessibilityIdentifier("takeover-cancel-button")
        } message: {
            if let resolved = pendingResolution {
                Text(
                    "A checkout for this repo already exists:\n\(resolved.processDirectory.path)\n\nTake over management so the worktree can be cleaned up later?"
                )
            }
        }
        .sheet(isPresented: $showSaveProfileSheet) {
            SaveProfileSheet(
                suggestedName: selectedProfile?.name ?? "",
                cliType: selectedCLIType,
                onSave: { name in
                    saveCurrentFormAsProfile(name: name)
                    create()
                }
            )
        }
        .onAppear {
            if let pane = refreshingPane {
                sessionInput = pane.name
                selectedCLIType = pane.cliType
                selectedProfileID = pane.profileID
            }
            if !activeToolList.contains(selectedCLIType) {
                selectedCLIType = activeToolList.first ?? .claude
            }
            if !isRefreshing && selectedProfileID == nil {
                let filtered = appSettings.profiles.filter { activeToolList.contains($0.cliType) }
                selectedProfileID = filtered.first?.id
            }
            applyProfileOrDefaults()
            if !isRefreshing {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    isSessionInputFocused = true
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var profilePickerSection: some View {
        let profiles = appSettings.profiles.filter { activeToolList.contains($0.cliType) }
        if !profiles.isEmpty || selectedProfileID != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Profile", selection: $selectedProfileID) {
                    Text("Custom").tag(nil as UUID?)
                    ForEach(profiles) { profile in
                        HStack {
                            Text(profile.name)
                            Text("(\(profile.cliType.displayName))")
                                .foregroundStyle(.secondary)
                        }
                        .tag(profile.id as UUID?)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("new-pane-profile-picker")
                .onChange(of: selectedProfileID) { _, _ in
                    applyProfileOrDefaults()
                    worktreeSetupError = nil
                    showTakeoverDialog = false
                    isSessionInputFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private var cliPickerSection: some View {
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
                    initializeOptionStatesFromGlobal()
                    worktreeSetupError = nil
                    showTakeoverDialog = false
                    isSessionInputFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private var sessionNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session, branch, or worktree")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("auth-refactor, origin/feature, my-worktree, …", text: $sessionInput)
                .textFieldStyle(.roundedBorder)
                .focused($isSessionInputFocused)
                .onSubmit { create() }
                .accessibilityIdentifier("new-pane-name-field")
                .disabled(isBusy || isRefreshing)
            VStack(alignment: .leading, spacing: 4) {
                Text("Session name, branch ref, or worktree.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(worktreePathPreview)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                if let validation = validationError {
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
        }
    }

    @ViewBuilder
    private var cliOptionsSection: some View {
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
    }

    @ViewBuilder
    private var envVarSection: some View {
        if selectedCLIType == .claude {
            let availableEnvVars = appSettings.envVarOptions.filter(\.isAvailable)
            if !availableEnvVars.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Environment Variables")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(availableEnvVars) { envVar in
                            EnvVarToggleRow(envVar: envVar, state: envVarStateBinding(for: envVar))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("new-pane-cancel-button")
            if !isRefreshing {
                Button("Save Profile & Create") {
                    saveProfileName = selectedProfile?.name ?? ""
                    showSaveProfileSheet = true
                }
                .disabled(!canSubmit || (selectedProfile != nil && !isFormModifiedFromProfile))
                .accessibilityIdentifier("new-pane-save-profile-button")
            }
            Button(isRefreshing ? "Refresh" : "Create Pane") { create() }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
                .accessibilityIdentifier("new-pane-open-button")
        }
    }

    // MARK: - State management

    private func stateBinding(for option: CLIOptionConfig) -> Binding<OptionState> {
        Binding(
            get: { optionStates[option.id] ?? OptionState(enabled: option.isDefaultEnabled, value: "") },
            set: { optionStates[option.id] = $0 }
        )
    }

    private func envVarStateBinding(for envVar: EnvVarConfig) -> Binding<OptionState> {
        Binding(
            get: {
                envVarStates[envVar.id]
                    ?? OptionState(enabled: envVar.isDefaultEnabled, value: envVar.defaultValue)
            },
            set: { envVarStates[envVar.id] = $0 }
        )
    }

    private func applyProfileOrDefaults() {
        if let profile = selectedProfile {
            applyProfile(profile)
        } else {
            initializeOptionStatesFromGlobal()
        }
    }

    private func applyProfile(_ profile: Profile) {
        selectedCLIType = profile.cliType
        optionStates = [:]
        for opt in profile.cliOptions {
            optionStates[opt.id] = OptionState(enabled: opt.isEnabled, value: opt.value ?? "")
        }
        envVarStates = [:]
        for ev in profile.envVars {
            envVarStates[ev.id] = OptionState(enabled: ev.isEnabled, value: ev.value)
        }
    }

    private func initializeOptionStatesFromGlobal() {
        optionStates = [:]
        for option in activeOptions where option.isAvailable {
            let enabled = option.isDefaultEnabled || (isRefreshing && option.id == "--continue")
            optionStates[option.id] = OptionState(enabled: enabled, value: "")
        }
        envVarStates = [:]
        if selectedCLIType == .claude {
            for envVar in appSettings.envVarOptions where envVar.isAvailable {
                let value = envVar.isDefaultEnabled ? envVar.defaultValue : ""
                envVarStates[envVar.id] = OptionState(enabled: envVar.isDefaultEnabled, value: value)
            }
        }
    }

    private func saveCurrentFormAsProfile(name: String) {
        let cliOptions = activeOptions.filter(\.isAvailable).map { opt in
            let state = optionStates[opt.id] ?? OptionState(enabled: false, value: "")
            return ProfileCLIOption(
                id: opt.id,
                isEnabled: state.enabled,
                value: state.value.isEmpty ? nil : state.value
            )
        }

        let envVars: [ProfileEnvVar]
        if selectedCLIType == .claude {
            envVars = appSettings.envVarOptions.filter(\.isAvailable).map { ev in
                let state = envVarStates[ev.id] ?? OptionState(enabled: false, value: "")
                return ProfileEnvVar(id: ev.id, isEnabled: state.enabled, value: state.value)
            }
        } else {
            envVars = []
        }

        let profile = Profile(
            name: name,
            cliType: selectedCLIType,
            cliOptions: cliOptions,
            envVars: envVars,
            statusLineConfig: nil
        )
        appSettings.profiles.append(profile)
        selectedProfileID = profile.id
        SettingsPersistence.saveProfiles(appSettings: appSettings)
    }

    // MARK: - Create flow

    private func create() {
        guard canSubmit else { return }
        let trimmed = trimmedInput
        guard !trimmed.isEmpty, validationError == nil else { return }
        isCreating = true
        worktreeSetupError = nil
        let extraArgs = buildExtraArgs()
        let extraEnvVars = buildExtraEnvVars()

        if let pane = refreshingPane {
            tab.refreshPaneWithArgs(
                pane, extraArgs: extraArgs, cliType: selectedCLIType, extraEnvVars: extraEnvVars)
            pane.profileID = selectedProfileID
            resetForm()
            dismiss()
            return
        }

        Task {
            do {
                let defaultBranch: String? = appSettings.isDefaultBranchEnabled ? appSettings.defaultBranch : nil
                let resolved = try await tab.resolveOrAttachWorktree(
                    userRef: trimmed,
                    defaultBranch: defaultBranch,
                    baseRef: appSettings.worktreeBaseRef
                )
                await MainActor.run {
                    if appState.isCheckoutInUse(directory: tab.directory, checkout: resolved.checkoutURL) {
                        isCreating = false
                        worktreeSetupError = "A pane with this worktree is already open."
                        return
                    }

                    if resolved.isExternalTakeover {
                        switch appSettings.existingWorktreeManagement {
                        case .always:
                            finishCreate(
                                resolved: resolved, managed: true, extraArgs: extraArgs,
                                extraEnvVars: extraEnvVars)
                        case .ask:
                            isCreating = false
                            pendingResolution = resolved
                            pendingExtraArgs = extraArgs
                            pendingExtraEnvVars = extraEnvVars
                            showTakeoverDialog = true
                        case .never:
                            finishCreate(
                                resolved: resolved, managed: false, extraArgs: extraArgs,
                                extraEnvVars: extraEnvVars)
                        }
                    } else {
                        finishCreate(
                            resolved: resolved, managed: true, extraArgs: extraArgs,
                            extraEnvVars: extraEnvVars)
                    }
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    applyResolveError(error)
                }
            }
        }
    }

    private func finishCreate(
        resolved: ResolvedWorktree, managed: Bool, extraArgs: [String],
        extraEnvVars: [String: String] = [:]
    ) {
        pendingResolution = nil
        pendingExtraArgs = []
        pendingExtraEnvVars = [:]
        resetForm()

        let statusLineOverride = selectedProfile?.statusLineConfig

        tab.addPane(
            name: resolved.paneTitle,
            extraArgs: extraArgs,
            cliType: selectedCLIType,
            worktreeDirectory: resolved.processDirectory,
            worktreeIsManaged: managed,
            extraEnvVars: extraEnvVars,
            profileID: selectedProfileID,
            statusLineConfigOverride: statusLineOverride
        )
        if let pane = tab.panes.last {
            pane.wireTerminalBellForNotifications(appState: appState, tab: tab, isPriority: isPriority)
        }
        appState.setActivePane(id: tab.panes.last?.id)
        SessionPersistence.save(appState: appState)
        dismiss()
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

    private func resetForm() {
        sessionInput = ""
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

    private func buildExtraEnvVars() -> [String: String] {
        guard selectedCLIType == .claude else { return [:] }
        var envVars: [String: String] = [:]
        for envVar in appSettings.envVarOptions where envVar.isAvailable {
            guard let state = envVarStates[envVar.id], state.enabled else { continue }
            let value = state.value.trimmingCharacters(in: .whitespaces)
            if !value.isEmpty {
                envVars[envVar.id] = value
            }
        }
        return envVars
    }
}

// MARK: - Save Profile Sheet

private struct SaveProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    let suggestedName: String
    let cliType: CLIType
    let onSave: (String) -> Void

    @State private var profileName = ""
    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Save Profile")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Profile Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Complex Task, Quick Side Quest, …", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit { if isValid { submit() } }
                Text("CLI: \(cliType.displayName)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save & Create") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear {
            profileName = suggestedName
            isFocused = true
        }
    }

    private func submit() {
        guard isValid else { return }
        onSave(profileName.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}

// MARK: - Reusable rows

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
            if case .string(let placeholder) = option.optionType {
                TextField(placeholder, text: $state.value)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!state.enabled)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct EnvVarToggleRow: View {
    let envVar: EnvVarConfig
    @Binding var state: OptionState

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle(isOn: $state.enabled) {
                Text(envVar.id)
                    .font(.system(.body, design: .monospaced))
                    .font(.caption)
            }
            TextField("Value", text: $state.value)
                .textFieldStyle(.roundedBorder)
                .disabled(!state.enabled)
                .frame(maxWidth: .infinity)
        }
    }
}
