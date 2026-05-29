import SwiftUI

enum ProfileEditorMode: Identifiable {
    case new
    case edit(Profile)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let profile): return profile.id.uuidString
        }
    }

    var profile: Profile? {
        switch self {
        case .new: return nil
        case .edit(let profile): return profile
        }
    }
}

struct ProfilesContent: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var editorMode: ProfileEditorMode?

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            if appSettings.profiles.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.rectangle.stack")
                            .font(.system(size: 36))
                            .foregroundStyle(.quaternary)
                        Text("No profiles yet")
                            .foregroundStyle(.secondary)
                        Text("Create a profile to save your preferred CLI configuration for quick reuse.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                Section("Profiles") {
                    ForEach(Array(appSettings.profiles.enumerated()), id: \.element.id) { index, profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(profile.name)
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                    Text(profile.cliType.displayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 8)
                                        .background(.quaternary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .foregroundStyle(.secondary)
                                    if profile.statusLineConfig != nil {
                                        Text("Custom status line")
                                            .font(.caption2)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 8)
                                            .background(.quaternary)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(profileSummary(profile))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                appSettings.profiles.swapAt(index, index - 1)
                                SettingsPersistence.saveProfiles(appSettings: appSettings)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(index == 0 ? .tertiary : .secondary)
                            .disabled(index == 0)
                            .accessibilityIdentifier("profile-move-up-\(profile.id)")

                            Button {
                                appSettings.profiles.swapAt(index, index + 1)
                                SettingsPersistence.saveProfiles(appSettings: appSettings)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(index == appSettings.profiles.count - 1 ? .tertiary : .secondary)
                            .disabled(index == appSettings.profiles.count - 1)
                            .accessibilityIdentifier("profile-move-down-\(profile.id)")

                            Menu {
                                Button("Edit") {
                                    editorMode = .edit(profile)
                                }
                                Button("Duplicate") {
                                    var copy = profile
                                    copy.id = UUID()
                                    copy.name = "\(profile.name) Copy"
                                    appSettings.profiles.append(copy)
                                    SettingsPersistence.saveProfiles(appSettings: appSettings)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    appSettings.profiles.removeAll { $0.id == profile.id }
                                    SettingsPersistence.saveProfiles(appSettings: appSettings)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 24)
                        }
                    }
                }
            }
            Section {
                Button {
                    editorMode = .new
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editorMode) { mode in
            ProfileEditorSheet(
                profile: mode.profile,
                appSettings: appSettings,
                onSave: { saved in
                    if let index = appSettings.profiles.firstIndex(where: { $0.id == saved.id }) {
                        appSettings.profiles[index] = saved
                    } else {
                        appSettings.profiles.append(saved)
                    }
                    SettingsPersistence.saveProfiles(appSettings: appSettings)
                }
            )
        }
    }

    private func profileSummary(_ profile: Profile) -> String {
        let flagCount = profile.cliOptions.filter(\.isEnabled).count
        let envCount = profile.envVars.filter(\.isEnabled).count
        var parts: [String] = []
        if flagCount > 0 {
            parts.append("\(flagCount) flag\(flagCount == 1 ? "" : "s")")
        }
        if envCount > 0 {
            parts.append("\(envCount) env var\(envCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }
}

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let profile: Profile?
    let appSettings: AppSettings
    let onSave: (Profile) -> Void

    @State private var name: String = ""
    @State private var cliType: CLIType = .claude
    @State private var optionStates: [String: ProfileEditorOptionState] = [:]
    @State private var envVarStates: [String: ProfileEditorOptionState] = [:]
    @State private var useCustomStatusLine = false
    @State private var statusLineConfig = StatusLineConfig()
    /// True once we seeded from disk or after copying from global settings on first toggle.
    @State private var didSeedCustomStatusLineFromGlobal = false
    @State private var showHiddenOptions = false
    @State private var showHiddenEnvVars = false

    @FocusState private var isNameFocused: Bool

    private var activeToolList: [CLIType] {
        CLIType.allCases.filter { appSettings.isActive($0) }
    }

    private var activeOptions: [CLIOptionConfig] {
        switch cliType {
        case .claude: return appSettings.cliOptions
        case .codex: return appSettings.codexCliOptions
        case .cursor: return appSettings.cursorCliOptions
        case .opencode: return appSettings.opencodeCliOptions
        case .shell: return []
        }
    }

    private var hiddenOptions: [CLIOptionConfig] {
        activeOptions.filter { !$0.isAvailable }
    }

    private var hiddenEnvVars: [EnvVarConfig] {
        appSettings.envVarOptions.filter { !$0.isAvailable }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(profile == nil ? "New Profile" : "Edit Profile")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Complex Task, Quick Side Quest, …", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .focused($isNameFocused)
                            .accessibilityIdentifier("profile-editor-name-field")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CLI")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("CLI", selection: $cliType) {
                            ForEach(activeToolList, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: cliType) { _, _ in
                            initializeFromGlobal()
                        }
                    }

                    let available = activeOptions.filter(\.isAvailable)
                    if !available.isEmpty || !hiddenOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CLI Options")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !available.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(available) { option in
                                            ProfileEditorOptionRow(
                                                option: option,
                                                state: editorStateBinding(for: option.id)
                                            )
                                        }
                                    }
                                }
                                .frame(maxHeight: 160)
                            }
                            if !hiddenOptions.isEmpty {
                                Button {
                                    showHiddenOptions.toggle()
                                } label: {
                                    Text(showHiddenOptions ? "Fewer options" : "Show all options")
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("profile-editor-show-hidden-options-button")

                                if showHiddenOptions {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(hiddenOptions) { option in
                                                ProfileEditorHiddenOptionRow(
                                                    option: option,
                                                    state: editorStateBinding(for: option.id),
                                                    onAddToGlobal: { onAddToGlobal(optionID: option.id) }
                                                )
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 160)
                                }
                            }
                        }
                    }

                    if cliType == .claude {
                        let availableEnvVars = appSettings.envVarOptions.filter(\.isAvailable)
                        if !availableEnvVars.isEmpty || !hiddenEnvVars.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Environment Variables")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if !availableEnvVars.isEmpty {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(availableEnvVars) { envVar in
                                                ProfileEditorEnvVarRow(
                                                    envVar: envVar,
                                                    state: editorEnvVarStateBinding(for: envVar.id)
                                                )
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 120)
                                }
                                if !hiddenEnvVars.isEmpty {
                                    Button {
                                        showHiddenEnvVars.toggle()
                                    } label: {
                                        Text(showHiddenEnvVars ? "Fewer options" : "Show all options")
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("profile-editor-show-hidden-env-vars-button")

                                    if showHiddenEnvVars {
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 6) {
                                                ForEach(hiddenEnvVars) { envVar in
                                                    ProfileEditorHiddenEnvVarRow(
                                                        envVar: envVar,
                                                        state: editorEnvVarStateBinding(for: envVar.id),
                                                        onAddToGlobal: { onAddToGlobalEnvVar(id: envVar.id) }
                                                    )
                                                }
                                            }
                                        }
                                        .frame(maxHeight: 120)
                                    }
                                }
                            }
                        }
                    }

                    Toggle(isOn: $useCustomStatusLine) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Status Line")
                                .font(.subheadline)
                            Text("Override the global status line for panes using this profile.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: useCustomStatusLine) { _, isOn in
                        guard isOn else { return }
                        if !didSeedCustomStatusLineFromGlobal {
                            statusLineConfig = appSettings.statusLineConfig
                            didSeedCustomStatusLineFromGlobal = true
                        }
                    }

                    if useCustomStatusLine {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(
                                "Customize chips and rows for panes created with this profile. GitHub PR tracking still follows Settings → Status Line → GitHub PR Tracking."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Form {
                                StatusLineConfigLayoutEditor(
                                    config: $statusLineConfig,
                                    filterCLI: cliType,
                                    phases: .full,
                                    onPersist: {})
                            }
                            .formStyle(.grouped)
                        }
                    }
                }
                .padding(24)
                .frame(width: 420)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding(24)
        }
        .frame(width: 420)
        .onAppear {
            if let existing = profile {
                name = existing.name
                cliType = existing.cliType
                for opt in existing.cliOptions {
                    optionStates[opt.id] = ProfileEditorOptionState(
                        enabled: opt.isEnabled, value: opt.value ?? "",
                        showOnPaneCreate: opt.showOnPaneCreate)
                }
                for ev in existing.envVars {
                    envVarStates[ev.id] = ProfileEditorOptionState(
                        enabled: ev.isEnabled, value: ev.value,
                        showOnPaneCreate: ev.showOnPaneCreate)
                }
                if let slc = existing.statusLineConfig {
                    useCustomStatusLine = true
                    statusLineConfig = slc
                }
                let availableIDs = Set(activeOptions.filter(\.isAvailable).map(\.id))
                if existing.cliOptions.contains(where: { $0.isEnabled && !availableIDs.contains($0.id) }) {
                    showHiddenOptions = true
                }
                let availableEnvIDs = Set(appSettings.envVarOptions.filter(\.isAvailable).map(\.id))
                if existing.envVars.contains(where: { $0.isEnabled && !availableEnvIDs.contains($0.id) }) {
                    showHiddenEnvVars = true
                }
            } else {
                if !activeToolList.contains(cliType) {
                    cliType = activeToolList.first ?? .claude
                }
                initializeFromGlobal()
            }
            didSeedCustomStatusLineFromGlobal = profile?.statusLineConfig != nil
            isNameFocused = true
        }
    }

    private func initializeFromGlobal() {
        optionStates = [:]
        for option in activeOptions where option.isAvailable {
            optionStates[option.id] = ProfileEditorOptionState(
                enabled: option.isDefaultEnabled, value: "")
        }
        envVarStates = [:]
        if cliType == .claude {
            for envVar in appSettings.envVarOptions where envVar.isAvailable {
                envVarStates[envVar.id] = ProfileEditorOptionState(
                    enabled: envVar.isDefaultEnabled, value: envVar.defaultValue)
            }
        }
    }

    private func editorStateBinding(for id: String) -> Binding<ProfileEditorOptionState> {
        Binding(
            get: { optionStates[id] ?? ProfileEditorOptionState(enabled: false, value: "") },
            set: { optionStates[id] = $0 }
        )
    }

    private func editorEnvVarStateBinding(for id: String) -> Binding<ProfileEditorOptionState> {
        Binding(
            get: { envVarStates[id] ?? ProfileEditorOptionState(enabled: false, value: "") },
            set: { envVarStates[id] = $0 }
        )
    }

    private func persistCLIOptions() {
        switch cliType {
        case .claude: SettingsPersistence.save(appSettings: appSettings)
        case .codex: SettingsPersistence.saveCodexOptions(appSettings: appSettings)
        case .cursor: SettingsPersistence.saveCursorOptions(appSettings: appSettings)
        case .opencode: SettingsPersistence.saveOpenCodeOptions(appSettings: appSettings)
        case .shell: break
        }
    }

    private func onAddToGlobal(optionID: String) {
        switch cliType {
        case .claude:
            if let i = appSettings.cliOptions.firstIndex(where: { $0.id == optionID }) {
                appSettings.cliOptions[i].isAvailable = true
            }
        case .codex:
            if let i = appSettings.codexCliOptions.firstIndex(where: { $0.id == optionID }) {
                appSettings.codexCliOptions[i].isAvailable = true
            }
        case .cursor:
            if let i = appSettings.cursorCliOptions.firstIndex(where: { $0.id == optionID }) {
                appSettings.cursorCliOptions[i].isAvailable = true
            }
        case .opencode:
            if let i = appSettings.opencodeCliOptions.firstIndex(where: { $0.id == optionID }) {
                appSettings.opencodeCliOptions[i].isAvailable = true
            }
        case .shell:
            break
        }
        persistCLIOptions()
    }

    private func onAddToGlobalEnvVar(id: String) {
        if let i = appSettings.envVarOptions.firstIndex(where: { $0.id == id }) {
            appSettings.envVarOptions[i].isAvailable = true
        }
        SettingsPersistence.saveEnvVarOptions(appSettings: appSettings)
    }

    private func save() {
        guard isValid else { return }
        let visibleOptions = activeOptions.filter(\.isAvailable).map { opt in
            let state = optionStates[opt.id] ?? ProfileEditorOptionState(enabled: false, value: "")
            return ProfileCLIOption(
                id: opt.id,
                isEnabled: state.enabled,
                value: state.value.isEmpty ? nil : state.value,
                showOnPaneCreate: state.showOnPaneCreate
            )
        }
        let hiddenEnabled = hiddenOptions.compactMap { opt -> ProfileCLIOption? in
            guard let state = optionStates[opt.id], state.enabled else { return nil }
            return ProfileCLIOption(
                id: opt.id, isEnabled: true,
                value: state.value.isEmpty ? nil : state.value,
                showOnPaneCreate: state.showOnPaneCreate)
        }
        let cliOptions = visibleOptions + hiddenEnabled

        let envVars: [ProfileEnvVar]
        if cliType == .claude {
            let visibleEnvVars = appSettings.envVarOptions.filter(\.isAvailable).map { ev in
                let state = envVarStates[ev.id] ?? ProfileEditorOptionState(enabled: false, value: "")
                return ProfileEnvVar(
                    id: ev.id, isEnabled: state.enabled, value: state.value,
                    showOnPaneCreate: state.showOnPaneCreate)
            }
            let hiddenEnabledEnvVars = hiddenEnvVars.compactMap { ev -> ProfileEnvVar? in
                guard let state = envVarStates[ev.id], state.enabled else { return nil }
                return ProfileEnvVar(
                    id: ev.id, isEnabled: true, value: state.value,
                    showOnPaneCreate: state.showOnPaneCreate)
            }
            envVars = visibleEnvVars + hiddenEnabledEnvVars
        } else {
            envVars = []
        }

        let saved = Profile(
            id: profile?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            cliType: cliType,
            cliOptions: cliOptions,
            envVars: envVars,
            statusLineConfig: useCustomStatusLine ? statusLineConfig : nil
        )
        onSave(saved)
        dismiss()
    }
}

private struct ProfileEditorOptionState {
    var enabled: Bool
    var value: String
    var showOnPaneCreate: Bool = false
}

private struct ProfileEditorOptionRow: View {
    let option: CLIOptionConfig
    @Binding var state: ProfileEditorOptionState

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
            HStack(spacing: 4) {
                Text("Show")
                    .font(.caption)
                Toggle("Show", isOn: $state.showOnPaneCreate)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .help("Show this option in the New Pane sheet when this profile is selected.")
            }
        }
    }
}

private struct ProfileEditorEnvVarRow: View {
    let envVar: EnvVarConfig
    @Binding var state: ProfileEditorOptionState

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
            HStack(spacing: 4) {
                Text("Show")
                    .font(.caption)
                Toggle("Show", isOn: $state.showOnPaneCreate)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .help("Show this option in the New Pane sheet when this profile is selected.")
            }
        }
    }
}

private struct ProfileEditorHiddenOptionRow: View {
    let option: CLIOptionConfig
    @Binding var state: ProfileEditorOptionState
    let onAddToGlobal: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle(isOn: $state.enabled) {
                Text(option.id)
                    .font(.system(.body, design: .monospaced))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if case .string(let placeholder) = option.optionType {
                TextField(placeholder, text: $state.value)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!state.enabled)
                    .frame(maxWidth: .infinity)
            }
            if state.enabled {
                Button("Show in all profiles", action: onAddToGlobal)
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

private struct ProfileEditorHiddenEnvVarRow: View {
    let envVar: EnvVarConfig
    @Binding var state: ProfileEditorOptionState
    let onAddToGlobal: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle(isOn: $state.enabled) {
                Text(envVar.id)
                    .font(.system(.body, design: .monospaced))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
