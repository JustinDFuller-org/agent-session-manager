import AppKit
import SwiftUI

struct NewPaneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    let tab: Tab
    var refreshingPane: Pane?

    @State private var sessionInput = ""
    @State private var selectedHarness: Harness = .claude
    @State private var selectedProfileID: UUID?
    @State private var optionStates: [String: OptionState] = [:]
    @State private var envVarStates: [String: OptionState] = [:]
    @State private var isPriority = false

    @State private var showSaveProfileSheet = false
    @State private var saveProfileName = ""
    @State private var showHiddenOptions = false
    @State private var showHiddenEnvVars = false

    @FocusState private var isSessionInputFocused: Bool

    private var activeToolList: [Harness] {
        Harness.allCases.filter { appSettings.isActive($0) }
    }

    private var activeOptions: [CLIOptionConfig] {
        switch selectedHarness {
        case .claude: return appSettings.cliOptions
        case .codex: return appSettings.codexCliOptions
        case .cursor: return appSettings.cursorCliOptions
        case .shell: return []
        }
    }

    private var trimmedInput: String {
        sessionInput.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard !activeToolList.isEmpty else { return false }
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

    private var visibleCLIOptions: [CLIOptionConfig] {
        let allAvailable = activeOptions.filter(\.isAvailable)
        guard let profile = selectedProfile else { return allAvailable }
        let showSet = Set(profile.cliOptions.filter(\.showOnPaneCreate).map(\.id))
        return allAvailable.filter { showSet.contains($0.id) }
    }

    private var visibleEnvVars: [EnvVarConfig] {
        let allAvailable = appSettings.envVarOptions.filter(\.isAvailable)
        guard let profile = selectedProfile else { return allAvailable }
        let showSet = Set(profile.envVars.filter(\.showOnPaneCreate).map(\.id))
        return allAvailable.filter { showSet.contains($0.id) }
    }

    private var hiddenCLIOptions: [CLIOptionConfig] {
        activeOptions.filter { !$0.isAvailable }
    }

    private var hiddenEnvVarOptions: [EnvVarConfig] {
        appSettings.envVarOptions.filter { !$0.isAvailable }
    }

    private var isFormModifiedFromProfile: Bool {
        guard let profile = selectedProfile else { return true }
        if selectedHarness != profile.harness { return true }
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
            hiddenCLIOptionsSection
            envVarSection
            hiddenEnvVarSection

            actionButtons
        }
        .padding(24)
        .frame(minWidth: 620, idealWidth: 620, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
        .sheet(isPresented: $showSaveProfileSheet) {
            SaveProfileSheet(
                suggestedName: selectedProfile?.name ?? "",
                harness: selectedHarness,
                onSave: { name in
                    saveCurrentFormAsProfile(name: name)
                    create()
                }
            )
        }
        .onAppear {
            if let pane = refreshingPane {
                sessionInput = pane.name
                selectedHarness = pane.harness
                selectedProfileID = pane.profileID
            }
            if !activeToolList.contains(selectedHarness) {
                selectedHarness = activeToolList.first ?? .claude
            }
            if !isRefreshing && selectedProfileID == nil {
                let filtered = appSettings.profiles.filter { activeToolList.contains($0.harness) }
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
        let profiles = appSettings.profiles.filter { activeToolList.contains($0.harness) }
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
                            Text("(\(profile.harness.displayName))")
                                .foregroundStyle(.secondary)
                        }
                        .tag(profile.id as UUID?)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("new-pane-profile-picker")
                .onChange(of: selectedProfileID) { _, _ in
                    applyProfileOrDefaults()
                    isSessionInputFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private var cliPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Harness")
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
                Picker("Harness", selection: $selectedHarness) {
                    ForEach(activeToolList, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("new-pane-cli-picker")
                .onChange(of: selectedHarness) { _, _ in
                    initializeOptionStatesFromGlobal()
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
                .disabled(isRefreshing)
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
            }
        }
    }

    @ViewBuilder
    private var cliOptionsSection: some View {
        if !visibleCLIOptions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("CLI Options")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleCLIOptions) { option in
                        CLIOptionToggleRow(option: option, state: stateBinding(for: option))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var envVarSection: some View {
        if selectedHarness == .claude {
            if !visibleEnvVars.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Environment Variables")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(visibleEnvVars) { envVar in
                            EnvVarToggleRow(envVar: envVar, state: envVarStateBinding(for: envVar))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var hiddenCLIOptionsSection: some View {
        if !hiddenCLIOptions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    showHiddenOptions.toggle()
                } label: {
                    Text(showHiddenOptions ? "Fewer options" : "Show all options")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("new-pane-show-hidden-options-button")

                if showHiddenOptions {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(hiddenCLIOptions) { option in
                            HiddenCLIOptionToggleRow(
                                option: option,
                                state: stateBinding(for: option),
                                onAddToGlobal: { newPaneAddToGlobal(optionID: option.id) }
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var hiddenEnvVarSection: some View {
        if selectedHarness == .claude && !hiddenEnvVarOptions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    showHiddenEnvVars.toggle()
                } label: {
                    Text(showHiddenEnvVars ? "Fewer options" : "Show all options")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("new-pane-show-hidden-env-vars-button")

                if showHiddenEnvVars {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(hiddenEnvVarOptions) { envVar in
                            HiddenEnvVarToggleRow(
                                envVar: envVar,
                                state: envVarStateBinding(for: envVar),
                                onAddToGlobal: { newPaneAddToGlobalEnvVar(id: envVar.id) }
                            )
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
        selectedHarness = profile.harness
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
        if selectedHarness == .claude {
            for envVar in appSettings.envVarOptions where envVar.isAvailable {
                let value = envVar.isDefaultEnabled ? envVar.defaultValue : ""
                envVarStates[envVar.id] = OptionState(enabled: envVar.isDefaultEnabled, value: value)
            }
        }
    }

    private func saveCurrentFormAsProfile(name: String) {
        let cliOptions = activeOptions.filter(\.isAvailable).map { opt in
            let state = optionStates[opt.id] ?? OptionState(enabled: false, value: "")
            let showOnCreate = selectedProfile?.cliOptions.first { $0.id == opt.id }?.showOnPaneCreate ?? false
            return ProfileCLIOption(
                id: opt.id,
                isEnabled: state.enabled,
                value: state.value.isEmpty ? nil : state.value,
                showOnPaneCreate: showOnCreate
            )
        }

        let envVars: [ProfileEnvVar]
        if selectedHarness == .claude {
            envVars = appSettings.envVarOptions.filter(\.isAvailable).map { ev in
                let state = envVarStates[ev.id] ?? OptionState(enabled: false, value: "")
                let showOnCreate = selectedProfile?.envVars.first { $0.id == ev.id }?.showOnPaneCreate ?? false
                return ProfileEnvVar(
                    id: ev.id, isEnabled: state.enabled, value: state.value,
                    showOnPaneCreate: showOnCreate)
            }
        } else {
            envVars = []
        }

        let profile = Profile(
            name: name,
            harness: selectedHarness,
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
        let extraArgs = buildExtraArgs()
        let extraEnvVars = buildExtraEnvVars()

        if let pane = refreshingPane {
            tab.refreshPaneWithArgs(
                pane, extraArgs: extraArgs, harness: selectedHarness, extraEnvVars: extraEnvVars,
                appSettings: appSettings)
            pane.profileID = selectedProfileID
            resetForm()
            dismiss()
            return
        }

        let pane = tab.addPaneWithLoadingState(
            name: trimmed,
            harness: selectedHarness,
            worktreeIsManaged: true,
            profileID: selectedProfileID
        )
        pane.wireTerminalBellForNotifications(appState: appState, tab: tab, isPriority: isPriority)
        appState.setActivePane(id: pane.id)
        SessionPersistence.save(appState: appState)
        resetForm()
        dismiss()

        let defaultBranch: String? = appSettings.isDefaultBranchEnabled ? appSettings.defaultBranch : nil
        let worktreeBaseRef = appSettings.worktreeBaseRef
        let existingWorktreeManagement = appSettings.existingWorktreeManagement
        let autoSetSessionName = appSettings.autoSetSessionName
        let tabName = tab.name
        let harness = selectedHarness
        let statusLineOverride = selectedProfile?.statusLineConfig

        Task {
            do {
                let resolved = try await tab.resolveOrAttachWorktree(
                    userRef: trimmed,
                    defaultBranch: defaultBranch,
                    baseRef: worktreeBaseRef
                )

                let inUse = await MainActor.run {
                    appState.isCheckoutInUse(
                        directory: tab.directory,
                        checkout: resolved.checkoutURL,
                        excludingPaneID: pane.id)
                }
                if inUse {
                    await MainActor.run {
                        pane.setupState = .failed(error: "A pane with this worktree is already open.")
                    }
                    return
                }

                let managed: Bool
                if resolved.isExternalTakeover {
                    switch existingWorktreeManagement {
                    case .always:
                        managed = true
                    case .never:
                        managed = false
                    case .ask:
                        let response = await MainActor.run { () -> NSApplication.ModalResponse in
                            let alert = NSAlert()
                            alert.messageText = "Manage existing worktree?"
                            alert.informativeText =
                                "A checkout for this repo already exists:\n\(resolved.processDirectory.path)\n\nTake over management so the worktree can be cleaned up later?"
                            alert.addButton(withTitle: "Manage")
                            alert.addButton(withTitle: "Don't Manage")
                            alert.addButton(withTitle: "Cancel")
                            return alert.runModal()
                        }
                        switch response {
                        case .alertFirstButtonReturn:
                            managed = true
                        case .alertSecondButtonReturn:
                            managed = false
                        default:
                            await MainActor.run {
                                pane.setupState = .failed(error: "Cancelled.")
                            }
                            return
                        }
                    }
                } else {
                    managed = true
                }

                let effectiveExtraArgs = Tab.applyAutoSessionName(
                    tabName: tabName,
                    paneName: resolved.paneTitle,
                    extraArgs: extraArgs,
                    harness: harness,
                    enabled: autoSetSessionName
                )
                await MainActor.run {
                    tab.completeSetup(
                        for: pane,
                        resolved: resolved,
                        managed: managed,
                        effectiveExtraArgs: effectiveExtraArgs,
                        extraEnvVars: extraEnvVars,
                        statusLineConfigOverride: statusLineOverride,
                        appSettings: appSettings
                    )
                    SessionPersistence.save(appState: appState)
                }
            } catch {
                await MainActor.run {
                    pane.setupState = .failed(error: resolveErrorMessage(error))
                }
            }
        }
    }

    private func resolveErrorMessage(_ error: Error) -> String {
        if let wre = error as? WorktreeResolutionError {
            return wre.localizedDescription
        } else if let gitErr = error as? GitCommandError {
            return gitErr.localizedDescription
        } else {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Helpers

extension NewPaneSheet {
    private func resetForm() {
        sessionInput = ""
    }

    private func buildExtraArgs() -> [String] {
        var args: [String] = []
        for option in activeOptions {
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
        guard selectedHarness == .claude else { return [:] }
        var envVars: [String: String] = [:]
        for envVar in appSettings.envVarOptions {
            guard let state = envVarStates[envVar.id], state.enabled else { continue }
            let value = state.value.trimmingCharacters(in: .whitespaces)
            if !value.isEmpty {
                envVars[envVar.id] = value
            }
        }
        return envVars
    }

    private func newPaneAddToGlobal(optionID: String) {
        switch selectedHarness {
        case .claude:
            if let i = appSettings.cliOptions.firstIndex(where: { $0.id == optionID }) {
                appSettings.cliOptions[i].isAvailable = true
            }
            SettingsPersistence.save(appSettings: appSettings)
        case .codex:
            if let i = appSettings.codexCliOptions.firstIndex(where: { $0.id == optionID }) {
                appSettings.codexCliOptions[i].isAvailable = true
            }
            SettingsPersistence.saveCodexOptions(appSettings: appSettings)
        case .cursor:
            if let i = appSettings.cursorCliOptions.firstIndex(where: { $0.id == optionID }) {
                appSettings.cursorCliOptions[i].isAvailable = true
            }
            SettingsPersistence.saveCursorOptions(appSettings: appSettings)
        case .shell:
            break
        }
    }

    private func newPaneAddToGlobalEnvVar(id: String) {
        if let i = appSettings.envVarOptions.firstIndex(where: { $0.id == id }) {
            appSettings.envVarOptions[i].isAvailable = true
        }
        SettingsPersistence.saveEnvVarOptions(appSettings: appSettings)
    }
}

// MARK: - Save Profile Sheet

private struct SaveProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    let suggestedName: String
    let harness: Harness
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
                Text("Harness: \(harness.displayName)")
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
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if case .string(let placeholder) = option.optionType {
                    TextField(placeholder, text: $state.value)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!state.enabled)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)
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
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Value", text: $state.value)
                .textFieldStyle(.roundedBorder)
                .disabled(!state.enabled)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct HiddenCLIOptionToggleRow: View {
    let option: CLIOptionConfig
    @Binding var state: OptionState
    let onAddToGlobal: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle(isOn: $state.enabled) {
                Text(option.id)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if case .string(let placeholder) = option.optionType {
                    TextField(placeholder, text: $state.value)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!state.enabled)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)
            if state.enabled {
                Button("Show in all profiles", action: onAddToGlobal)
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

private struct HiddenEnvVarToggleRow: View {
    let envVar: EnvVarConfig
    @Binding var state: OptionState
    let onAddToGlobal: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle(isOn: $state.enabled) {
                Text(envVar.id)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Value", text: $state.value)
                .textFieldStyle(.roundedBorder)
                .disabled(!state.enabled)
                .frame(maxWidth: .infinity)
            if state.enabled {
                Button("Show in all profiles", action: onAddToGlobal)
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
