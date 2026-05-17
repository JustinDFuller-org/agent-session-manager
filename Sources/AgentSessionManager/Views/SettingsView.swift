import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        TabView {
            GeneralContent()
                .environment(appSettings)
                .tabItem { Label("General", systemImage: "gear") }
            ProfilesContent()
                .environment(appSettings)
                .tabItem { Label("Profiles", systemImage: "person.crop.rectangle.stack") }
            ToolsContent()
                .environment(appSettings)
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
            UnifiedCLIOptionsContent()
                .environment(appSettings)
                .tabItem { Label("CLI Options", systemImage: "terminal") }
            WorktreesContent()
                .environment(appSettings)
                .tabItem { Label("Worktrees", systemImage: "folder.badge.gearshape") }
            KeyboardShortcutsContent()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            StatusLineContent()
                .environment(appSettings)
                .tabItem { Label("Status Line", systemImage: "chart.bar") }
            NotificationsContent()
                .environment(appSettings)
                .tabItem { Label("Notifications", systemImage: "bell") }
        }
        .frame(width: 740, height: 580)
    }
}

private struct DefaultValueLabel: View {
    let value: String

    var body: some View {
        Text("Default: \(value)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

private struct GeneralContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Configure general app behavior.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Git")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Default Branch")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Automatically fetch and create worktrees from a default branch.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Default Branch", isOn: $appSettings.isDefaultBranchEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-default-branch-toggle")
                                .onChange(of: appSettings.isDefaultBranchEnabled) {
                                    SettingsPersistence.saveDefaultBranch(appSettings: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        if appSettings.isDefaultBranchEnabled {
                            Divider().padding(.leading, 16)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Branch Name")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                    Text("Branch used as the base when creating new worktrees.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    DefaultValueLabel(value: "main")
                                }
                                Spacer()
                                TextField("", text: $appSettings.defaultBranch)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 120)
                                    .accessibilityIdentifier("settings-default-branch-field")
                                    .onChange(of: appSettings.defaultBranch) {
                                        SettingsPersistence.saveDefaultBranch(appSettings: appSettings)
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sessions")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Continue on Restart")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Resume the last conversation when Claude panes reopen after a restart.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Continue on Restart", isOn: $appSettings.continueOnRestart)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-continue-on-restart-toggle")
                                .onChange(of: appSettings.continueOnRestart) {
                                    SettingsPersistence.saveRestartSettings(appSettings: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto Session Name")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Passes --name <tab>/<pane> to Claude so sessions appear by name in claude resume and the terminal title. Skipped if --name is set manually in CLI Options."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Auto Session Name", isOn: $appSettings.autoSetSessionName)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-auto-session-name-toggle")
                                .onChange(of: appSettings.autoSetSessionName) {
                                    SettingsPersistence.saveSessionNameSettings(appSettings: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Terminal")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("When Process Exits")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(appSettings.exitBehavior.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "Show Prompt")
                            }
                            Spacer()
                            Picker("When Process Exits", selection: $appSettings.exitBehavior) {
                                ForEach(ExitBehavior.allCases, id: \.self) { behavior in
                                    Text(behavior.displayName).tag(behavior)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 240)
                            .accessibilityIdentifier("settings-exit-behavior-picker")
                            .onChange(of: appSettings.exitBehavior) {
                                SettingsPersistence.saveExitBehavior(appSettings: appSettings)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Scrollback Lines")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Number of lines kept in the terminal scroll buffer (100–1,000,000).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "500")
                            }
                            Spacer()
                            TextField(
                                "",
                                text: Binding(
                                    get: { String(appSettings.scrollbackLines) },
                                    set: { newValue in
                                        if let parsed = Int(newValue) {
                                            appSettings.scrollbackLines = min(1_000_000, max(100, parsed))
                                            SettingsPersistence.saveTerminalSettings(appSettings: appSettings)
                                        }
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 120)
                            .accessibilityIdentifier("settings-scrollback-lines-field")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Debug")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Debug Logging")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Append diagnostics to a trace file (see path below) instead of keeping them in memory."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Debug Logging", isOn: $appSettings.debugLoggingEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-debug-logging-toggle")
                                .onChange(of: appSettings.debugLoggingEnabled) {
                                    DebugLogger.shared.isEnabled = appSettings.debugLoggingEnabled
                                    DebugLogger.shared.syncFromAppSettings(appSettings)
                                    if !appSettings.debugLoggingEnabled {
                                        DebugLogger.shared.removeAllTracedPanes()
                                    }
                                    SettingsPersistence.saveDebugSettings(appSettings: appSettings)
                                    if appSettings.debugLoggingEnabled {
                                        DebugLogger.shared.logSystemInfo()
                                        DebugLogger.shared.logNotificationEnvironment(
                                            macOSBannerNotificationsEnabled: appSettings.isMacOSBannerNotificationsEnabled
                                        )
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Trace file path")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Leave empty for the default file under Application Support. ~ is expanded.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "~/Library/Application Support/…")
                            }
                            Spacer()
                            TextField("", text: $appSettings.debugLogFilePath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(minWidth: 220)
                                .accessibilityIdentifier("settings-debug-log-file-path")
                                .onChange(of: appSettings.debugLogFilePath) {
                                    DebugLogger.shared.syncFromAppSettings(appSettings)
                                    SettingsPersistence.saveDebugSettings(appSettings: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Max trace file size")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("When exceeded, older bytes are removed from the start of the file.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "15 MB")
                            }
                            Spacer()
                            Stepper(value: $appSettings.debugLogMaxSizeMegabytes, in: 1...512) {
                                Text("\(appSettings.debugLogMaxSizeMegabytes) MB")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minWidth: 72, alignment: .trailing)
                            }
                            .accessibilityIdentifier("settings-debug-log-max-mb-stepper")
                            .onChange(of: appSettings.debugLogMaxSizeMegabytes) {
                                DebugLogger.shared.syncFromAppSettings(appSettings)
                                SettingsPersistence.saveDebugSettings(appSettings: appSettings)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Include terminal snapshots")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "When debug logging is on, allow capturing all panes’ terminal text into the trace file from the debug sheet. You can also enable capture per pane from its context menu without this."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Include terminal snapshots", isOn: $appSettings.debugLogIncludeTerminalContents)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-debug-include-terminal-toggle")
                                .disabled(!appSettings.debugLoggingEnabled)
                                .onChange(of: appSettings.debugLogIncludeTerminalContents) {
                                    DebugLogger.shared.syncFromAppSettings(appSettings)
                                    SettingsPersistence.saveDebugSettings(appSettings: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }
}

private struct ProfilesContent: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var showEditor = false
    @State private var editingProfile: Profile?

    var body: some View {
        @Bindable var appSettings = appSettings
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(
                    "Create named profiles to quickly configure panes. Each profile saves the CLI tool, flags, environment variables, and optionally a custom status line. Global CLI Options settings seed new profiles but do not change saved ones."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if appSettings.profiles.isEmpty {
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
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profiles")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        VStack(spacing: 0) {
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
                                            editingProfile = profile
                                            showEditor = true
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                if index < appSettings.profiles.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Button {
                    editingProfile = nil
                    showEditor = true
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(20)
        }
        .sheet(isPresented: $showEditor) {
            ProfileEditorSheet(
                profile: editingProfile,
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
                    if !available.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CLI Options")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
                    }

                    if cliType == .claude {
                        let availableEnvVars = appSettings.envVarOptions.filter(\.isAvailable)
                        if !availableEnvVars.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Environment Variables")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                        VStack(alignment: .leading, spacing: 20) {
                            Text(
                                "Customize chips and rows for panes created with this profile. GitHub PR tracking still follows Settings → Status Line → GitHub PR Tracking."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            StatusLineConfigLayoutEditor(
                                config: $statusLineConfig,
                                filterCLI: cliType,
                                phases: .full,
                                onPersist: {})
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
                        enabled: opt.isEnabled, value: opt.value ?? "")
                }
                for ev in existing.envVars {
                    envVarStates[ev.id] = ProfileEditorOptionState(enabled: ev.isEnabled, value: ev.value)
                }
                if let slc = existing.statusLineConfig {
                    useCustomStatusLine = true
                    statusLineConfig = slc
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

    private func save() {
        guard isValid else { return }
        let cliOptions = activeOptions.filter(\.isAvailable).map { opt in
            let state = optionStates[opt.id] ?? ProfileEditorOptionState(enabled: false, value: "")
            return ProfileCLIOption(
                id: opt.id,
                isEnabled: state.enabled,
                value: state.value.isEmpty ? nil : state.value
            )
        }

        let envVars: [ProfileEnvVar]
        if cliType == .claude {
            envVars = appSettings.envVarOptions.filter(\.isAvailable).map { ev in
                let state = envVarStates[ev.id] ?? ProfileEditorOptionState(enabled: false, value: "")
                return ProfileEnvVar(id: ev.id, isEnabled: state.enabled, value: state.value)
            }
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
        }
    }
}

private struct ToolsContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(
                    "Select which AI tools are available when creating a new pane. Only active tools appear in the New Pane sheet."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Available Tools")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(CLIType.allCases.enumerated()), id: \.element) { index, tool in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tool.displayName)
                                    Text(tool.cliCommandDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fontDesign(.monospaced)
                                }
                                Spacer()
                                Toggle(
                                    tool.displayName,
                                    isOn: Binding(
                                        get: { appSettings.isActive(tool) },
                                        set: { active in
                                            appSettings.setActive(tool, active)
                                            SettingsPersistence.saveActiveTools(appSettings: appSettings)
                                        }
                                    )
                                )
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            if index < CLIType.allCases.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }
}

private struct WorktreesContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Configure worktree management behavior.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Created Worktrees")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Worktree Cleanup")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(appSettings.worktreeCleanupBehavior.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "Ask")
                            }
                            Spacer()
                            Picker("Worktree Cleanup", selection: $appSettings.worktreeCleanupBehavior) {
                                ForEach(WorktreeCleanupBehavior.allCases, id: \.self) { behavior in
                                    Text(behavior.displayName).tag(behavior)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 220)
                            .accessibilityIdentifier("settings-worktree-cleanup-picker")
                            .onChange(of: appSettings.worktreeCleanupBehavior) {
                                SettingsPersistence.saveWorktreeCleanup(appSettings: appSettings)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Base Ref")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(appSettings.worktreeBaseRef.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "Fresh")
                            }
                            Spacer()
                            Picker("Base Ref", selection: $appSettings.worktreeBaseRef) {
                                ForEach(WorktreeBaseRef.allCases, id: \.self) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 160)
                            .accessibilityIdentifier("settings-worktree-base-ref-picker")
                            .onChange(of: appSettings.worktreeBaseRef) {
                                SettingsPersistence.saveWorktreeBaseRef(appSettings: appSettings)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Existing Worktrees")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manage Existing Worktrees")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(appSettings.existingWorktreeManagement.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "Ask")
                            }
                            Spacer()
                            Picker("Manage Existing", selection: $appSettings.existingWorktreeManagement) {
                                ForEach(ExistingWorktreeManagement.allCases, id: \.self) { behavior in
                                    Text(behavior.displayName).tag(behavior)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 220)
                            .accessibilityIdentifier("settings-existing-worktree-management-picker")
                            .onChange(of: appSettings.existingWorktreeManagement) {
                                SettingsPersistence.saveExistingWorktreeManagement(appSettings: appSettings)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }
}

private struct UnifiedCLIOptionsContent: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var selectedTool: CLIType = .claude

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tool", selection: $selectedTool) {
                ForEach(CLIType.allCases, id: \.self) { tool in
                    Text(tool.displayName).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            switch selectedTool {
            case .claude:
                CLIOptionsContent(
                    options: Binding(
                        get: { appSettings.cliOptions },
                        set: { appSettings.cliOptions = $0 }
                    ),
                    onSave: { SettingsPersistence.save(appSettings: appSettings) },
                    customFlagFooter: "Custom flags may not be recognized by all Claude CLI versions.",
                    envVarOptions: Binding(
                        get: { appSettings.envVarOptions },
                        set: { appSettings.envVarOptions = $0 }
                    ),
                    onEnvVarSave: { SettingsPersistence.saveEnvVarOptions(appSettings: appSettings) }
                )
            case .codex:
                CLIOptionsContent(
                    options: Binding(
                        get: { appSettings.codexCliOptions },
                        set: { appSettings.codexCliOptions = $0 }
                    ),
                    onSave: { SettingsPersistence.saveCodexOptions(appSettings: appSettings) },
                    customFlagFooter: "Custom flags may not be recognized by all Codex CLI versions."
                )
            case .cursor:
                CLIOptionsContent(
                    options: Binding(
                        get: { appSettings.cursorCliOptions },
                        set: { appSettings.cursorCliOptions = $0 }
                    ),
                    onSave: { SettingsPersistence.saveCursorOptions(appSettings: appSettings) },
                    customFlagFooter: "Custom flags may not be recognized by all Cursor CLI versions."
                )
            case .opencode:
                CLIOptionsContent(
                    options: Binding(
                        get: { appSettings.opencodeCliOptions },
                        set: { appSettings.opencodeCliOptions = $0 }
                    ),
                    onSave: { SettingsPersistence.saveOpenCodeOptions(appSettings: appSettings) },
                    customFlagFooter: "Custom flags may not be recognized by all OpenCode CLI versions."
                )
            case .shell:
                EmptyView()
            }
        }
    }
}

private struct CLIOptionsContent: View {
    @Binding var options: [CLIOptionConfig]
    let onSave: () -> Void
    let customFlagFooter: String
    var envVarOptions: Binding<[EnvVarConfig]>?
    var onEnvVarSave: (() -> Void)?
    @State private var showAddCustomFlagSheet = false
    @State private var showAddCustomEnvVarSheet = false

    private var enabledOptions: [CLIOptionConfig] {
        options.filter { $0.isAvailable && !$0.isUserAdded }.sorted { $0.id < $1.id }
    }

    private var disabledOptions: [CLIOptionConfig] {
        options.filter { !$0.isAvailable && !$0.isUserAdded }.sorted { $0.id < $1.id }
    }

    private var customOptions: [CLIOptionConfig] {
        options.filter(\.isUserAdded).sorted { $0.id < $1.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(
                    "Configure which CLI options appear when creating a new pane. Options marked as default will be pre-checked in the New Pane dialog."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if !enabledOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Enabled")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(enabledOptions.enumerated()), id: \.element.id) { index, option in
                                let optIndex = options.firstIndex(where: { $0.id == option.id })!
                                CLIOptionRow(option: $options[optIndex], onChange: onSave)
                                    .padding(.horizontal, 16)
                                if index < enabledOptions.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Not Enabled")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(disabledOptions.enumerated()), id: \.element.id) { index, option in
                            let optIndex = options.firstIndex(where: { $0.id == option.id })!
                            CLIOptionRow(option: $options[optIndex], onChange: onSave)
                                .padding(.horizontal, 16)
                            if index < disabledOptions.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Options")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(customOptions.enumerated()), id: \.element.id) { index, option in
                            let optIndex = options.firstIndex(where: { $0.id == option.id })!
                            CustomCLIOptionRow(
                                option: $options[optIndex],
                                onChange: onSave,
                                onDelete: {
                                    options.removeAll { $0.id == option.id }
                                    onSave()
                                }
                            )
                            .padding(.horizontal, 16)
                            Divider().padding(.leading, 16)
                        }
                        Button {
                            showAddCustomFlagSheet = true
                        } label: {
                            Label("Add Custom Flag", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(customFlagFooter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                if let envBinding = envVarOptions, let envSave = onEnvVarSave {
                    EnvVarSections(
                        options: envBinding,
                        onSave: envSave,
                        showAddSheet: $showAddCustomEnvVarSheet
                    )
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showAddCustomFlagSheet) {
            AddCustomFlagSheet(existingIDs: options.map(\.id)) { id, isString in
                options.append(CLIOptionConfig.makeUserAdded(id: id, isString: isString))
                onSave()
            }
        }
        .sheet(isPresented: $showAddCustomEnvVarSheet) {
            if let envBinding = envVarOptions, let envSave = onEnvVarSave {
                AddCustomEnvVarSheet(existingIDs: envBinding.wrappedValue.map(\.id)) { id in
                    envBinding.wrappedValue.append(EnvVarConfig.makeUserAdded(id: id))
                    envSave()
                }
            }
        }
    }
}

private struct EnvVarSections: View {
    @Binding var options: [EnvVarConfig]
    let onSave: () -> Void
    @Binding var showAddSheet: Bool

    private var enabledOptions: [EnvVarConfig] {
        options.filter { $0.isAvailable && !$0.isUserAdded }.sorted { $0.id < $1.id }
    }

    private var disabledOptions: [EnvVarConfig] {
        options.filter { !$0.isAvailable && !$0.isUserAdded }.sorted { $0.id < $1.id }
    }

    private var customOptions: [EnvVarConfig] {
        options.filter(\.isUserAdded).sorted { $0.id < $1.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Environment Variables")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.leading, 4)
                Text(
                    "Configure which environment variables are set when launching Claude Code. Variables marked as default will be pre-enabled with their default value in the New Pane dialog."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            }

            if !enabledOptions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enabled Env Vars")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(enabledOptions.enumerated()), id: \.element.id) { index, option in
                            let optIndex = options.firstIndex(where: { $0.id == option.id })!
                            EnvVarOptionRow(option: $options[optIndex], onChange: onSave)
                                .padding(.horizontal, 16)
                            if index < enabledOptions.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Not Enabled Env Vars")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(Array(disabledOptions.enumerated()), id: \.element.id) { index, option in
                        let optIndex = options.firstIndex(where: { $0.id == option.id })!
                        EnvVarOptionRow(option: $options[optIndex], onChange: onSave)
                            .padding(.horizontal, 16)
                        if index < disabledOptions.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Env Vars")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(Array(customOptions.enumerated()), id: \.element.id) { index, option in
                        let optIndex = options.firstIndex(where: { $0.id == option.id })!
                        CustomEnvVarOptionRow(
                            option: $options[optIndex],
                            onChange: onSave,
                            onDelete: {
                                options.removeAll { $0.id == option.id }
                                onSave()
                            }
                        )
                        .padding(.horizontal, 16)
                        Divider().padding(.leading, 16)
                    }
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Custom Env Var", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Custom environment variables are passed to the Claude Code process.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
}

private struct KeyboardShortcutsContent: View {
    @AppStorage("keyBinding.newTabKey") var newTabKey = "t"
    @AppStorage("keyBinding.newPaneKey") var newPaneKey = "p"
    @AppStorage("keyBinding.closePaneKey") var closePaneKey = "w"
    @AppStorage("keyBinding.closeTabKey") var closeTabKey = "k"
    @AppStorage("keyBinding.openShellHereKey") var openShellHereKey = "s"
    @AppStorage("keyBinding.refreshPaneKey") var refreshPaneKey = "r"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(
                    "Customize keyboard shortcuts. Each shortcut uses ⌘ plus the key you specify. Changes take effect immediately."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Shortcuts")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        KeyBindingRow(
                            label: "New Tab", description: "Open the New Tab sheet", modifier: "⌘", key: $newTabKey)
                        Divider().padding(.leading, 16)
                        KeyBindingRow(
                            label: "New Pane in Current Tab", description: "Open the New Pane sheet", modifier: "⌘",
                            key: $newPaneKey)
                        Divider().padding(.leading, 16)
                        KeyBindingRow(
                            label: "Close Active Pane", description: "Close the focused pane", modifier: "⌘",
                            key: $closePaneKey)
                        Divider().padding(.leading, 16)
                        KeyBindingRow(
                            label: "Close Active Tab", description: "Close the current tab", modifier: "⌘",
                            key: $closeTabKey)
                        Divider().padding(.leading, 16)
                        KeyBindingRow(
                            label: "Open Shell Here",
                            description: "Open a new plain shell pane in the same working directory",
                            modifier: "⌘⇧",
                            key: $openShellHereKey)
                        Divider().padding(.leading, 16)
                        KeyBindingRow(
                            label: "Refresh Active Pane",
                            description: "Restart pane with fresh environment",
                            modifier: "⌘",
                            key: $refreshPaneKey)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Fixed Shortcuts")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("⌘1 – ⌘9")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Switch to tab by index")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Tab switching shortcuts are not configurable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .padding(20)
        }
    }
}

private struct KeyBindingRow: View {
    let label: String
    let description: String
    let modifier: String
    @Binding var key: String

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Spacer()
                HStack(alignment: .center, spacing: 4) {
                    Text(modifier)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 36)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .onChange(of: draft) {
                            let trimmed = String(draft.prefix(1)).lowercased()
                            if draft != trimmed {
                                draft = trimmed
                            }
                        }
                        .onChange(of: isFocused) {
                            if !isFocused {
                                if draft.isEmpty {
                                    draft = key
                                } else {
                                    key = draft
                                }
                            }
                        }
                        .onAppear { draft = key }
                }
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct CLIOptionRow: View {
    @Binding var option: CLIOptionConfig
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.id)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("Show", isOn: $option.isAvailable)
                        .toggleStyle(.checkbox)
                        .onChange(of: option.isAvailable) {
                            if !option.isAvailable {
                                option.isDefaultEnabled = false
                            }
                            onChange()
                        }
                    Toggle("Default on", isOn: $option.isDefaultEnabled)
                        .toggleStyle(.checkbox)
                        .disabled(!option.isAvailable)
                        .onChange(of: option.isDefaultEnabled) { onChange() }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CustomCLIOptionRow: View {
    @Binding var option: CLIOptionConfig
    let onChange: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(option.id)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        Text(option.customIsStringType ? "text" : "boolean")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("Show", isOn: $option.isAvailable)
                        .toggleStyle(.checkbox)
                        .onChange(of: option.isAvailable) {
                            if !option.isAvailable {
                                option.isDefaultEnabled = false
                            }
                            onChange()
                        }
                    Toggle("Default on", isOn: $option.isDefaultEnabled)
                        .toggleStyle(.checkbox)
                        .disabled(!option.isAvailable)
                        .onChange(of: option.isDefaultEnabled) { onChange() }
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct StatusLineEditorPhases: OptionSet {
    let rawValue: Int

    static let display = StatusLineEditorPhases(rawValue: 1 << 0)
    static let rows = StatusLineEditorPhases(rawValue: 1 << 1)
    static let full: StatusLineEditorPhases = [.display, .rows]
}

/// Chips, alignment, rows, and add-row controls for [`StatusLineConfig`]. Omit PR tracking —
/// that stays on [`AppSettings`].
private struct StatusLineConfigLayoutEditor: View {
    @Binding var config: StatusLineConfig
    var filterCLI: CLIType?
    let phases: StatusLineEditorPhases
    let onPersist: () -> Void

    var body: some View {
        Group {
            if phases.contains(.display) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            Text("Chip style")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Spacer()
                            Picker("Chip style", selection: chipStylePickerBinding) {
                                ForEach(ChipLabelStyle.allCases, id: \.self) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 160)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("Item alignment")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Spacer()
                            Picker("Item alignment", selection: rowAlignmentPickerBinding) {
                                ForEach(RowAlignment.allCases, id: \.self) { alignment in
                                    Text(alignment.displayName).tag(alignment)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 160)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            if phases.contains(.rows) {
                ForEach(Array(config.rows.enumerated()), id: \.element.id) { index, _ in
                    rowSection(rowIndex: index)
                }
                VStack(spacing: 0) {
                    Button {
                        touch { $0.rows.append(StatusLineRow()) }
                    } label: {
                        Label("Add Row", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var chipStylePickerBinding: Binding<ChipLabelStyle> {
        Binding(
            get: { config.chipLabelStyle },
            set: { newVal in touch { $0.chipLabelStyle = newVal } })
    }

    private var rowAlignmentPickerBinding: Binding<RowAlignment> {
        Binding(
            get: { config.rowAlignment },
            set: { newVal in touch { $0.rowAlignment = newVal } })
    }

    private func touch(_ update: (inout StatusLineConfig) -> Void) {
        var next = config
        update(&next)
        config = next
        onPersist()
    }

    private func unusedItemsEligibleForAddition() -> [StatusLineItem] {
        let base = StatusLineConfig.allItems.filter { !config.usedItemIDs.contains($0.id) }
        guard let cli = filterCLI else { return base }
        return base.filter { $0.supportedBy(cli) }
    }

    @ViewBuilder
    private func availabilityBadge(for availability: ToolAvailability) -> some View {
        switch availability {
        case .claudeOnly:
            Text("Claude only")
                .font(.caption2)
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.blue.opacity(0.1)))
        case .opencodeOnly:
            Text("OpenCode only")
                .font(.caption2)
                .foregroundStyle(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.purple.opacity(0.1)))
        case .claudeOrOpencode:
            Text("Claude + OpenCode")
                .font(.caption2)
                .foregroundStyle(.indigo)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.indigo.opacity(0.1)))
        case .all:
            Text("All tools")
                .font(.caption2)
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.green.opacity(0.1)))
        }
    }

    private func rowSection(rowIndex: Int) -> some View {
        let rowCount = config.rows.count
        let available = unusedItemsEligibleForAddition()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Row \(rowIndex + 1)")
                    .font(.headline)
                    .padding(.leading, 4)
                Spacer()
                Button {
                    touch { $0.rows.swapAt(rowIndex, rowIndex - 1) }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(rowIndex == 0)
                Button {
                    touch { $0.rows.swapAt(rowIndex, rowIndex + 1) }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(rowIndex == rowCount - 1)
                Button(role: .destructive) {
                    touch { $0.rows.remove(at: rowIndex) }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
            VStack(spacing: 0) {
                ForEach(config.rows[rowIndex].items) { item in
                    HStack {
                        Image(systemName: item.sfSymbol)
                            .frame(width: 16)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.label)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            let desc = itemDescription(for: item.id)
                            if !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        availabilityBadge(for: item.availability)
                        Button(role: .destructive) {
                            touch {
                                $0.rows[rowIndex].items.removeAll { $0.id == item.id }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Divider().padding(.leading, 16)
                }
                Menu {
                    if available.isEmpty {
                        Text(filterCLI == nil ? "All items are already used" : "No more items supported for this CLI")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(available) { item in
                            Button {
                                touch {
                                    $0.rows[rowIndex].items.append(item)
                                }
                            } label: {
                                HStack {
                                    Text(item.label)
                                    switch item.availability {
                                    case .claudeOnly:
                                        Text("Claude only")
                                            .font(.caption2)
                                            .foregroundStyle(.blue)
                                    case .opencodeOnly:
                                        Text("OpenCode only")
                                            .font(.caption2)
                                            .foregroundStyle(.purple)
                                    case .claudeOrOpencode:
                                        Text("Claude + OpenCode")
                                            .font(.caption2)
                                            .foregroundStyle(.indigo)
                                    case .all:
                                        Text("All tools")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func itemDescription(for id: String) -> String {
        switch id {
        case "model": return "Claude model name"
        case "worktree": return "Git worktree name"
        case "cost": return "Total session cost in USD (Claude only)"
        case "context": return "Context window usage with progress bar (Claude only)"
        case "effort": return "Effort level (Claude only)"
        case "thinking": return "Whether extended thinking is on or off (Claude only)"
        case "vimMode": return "Vim editor mode (Claude only)"
        case "agentName": return "Agent name (Claude only)"
        case "sessionName": return "Session name (Claude only)"
        case "worktreeBranch": return "Git branch for the worktree"
        case "gitWorktree": return "Git worktree path"
        case "linesAdded": return "Total lines added this session (Claude only)"
        case "linesRemoved": return "Total lines removed this session (Claude only)"
        case "duration": return "Total session duration"
        case "contextRemaining": return "Context window remaining percentage (Claude only)"
        case "inputTokens": return "Total input tokens used (Claude only)"
        case "outputTokens": return "Total output tokens used (Claude only)"
        case "rate5h": return "5-hour rate limit usage with progress bar (Claude only)"
        case "rate7d": return "7-day rate limit usage with progress bar (Claude only)"
        case "rate5hReset": return "Time until 5-hour rate limit resets (Claude only)"
        case "rate7dReset": return "Time until 7-day rate limit resets (Claude only)"
        case "version": return "Tool CLI version"
        case "outputStyle": return "Output style name (Claude only)"
        case "exceeds200k": return "Warning when context exceeds 200k tokens (Claude only)"
        case "pr": return "GitHub pull request status for the current branch"
        case "profileName": return "Selected profile name when the pane uses one"
        default: return ""
        }
    }
}

private struct StatusLineContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(
                    "Configure the info panel shown at the bottom of each pane. Items marked \"Claude only\" require Claude Code's statusLine hook. Items marked \"OpenCode only\" are populated via the OpenCode HTTP API. All other items work with any tool via git and process data."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings-status-line-description")

                StatusLineConfigLayoutEditor(
                    config: $appSettings.statusLineConfig,
                    filterCLI: nil,
                    phases: .display,
                    onPersist: {
                        SettingsPersistence.saveStatusLine(appSettings: appSettings)
                    })

                VStack(alignment: .leading, spacing: 6) {
                    Text("GitHub PR Tracking")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Track pull requests")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Detects the PR for the current git branch and shows its status in the status line. Requires the GitHub CLI (gh) installed and authenticated."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Track pull requests", isOn: $appSettings.githubPRTrackingEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .onChange(of: appSettings.githubPRTrackingEnabled) {
                                    SettingsPersistence.savePRTracking(appSettings: appSettings)
                                    NotificationCenter.default.post(
                                        name: .agentSessionManagerPRTrackingSettingChanged, object: nil)
                                }
                                .accessibilityIdentifier("settings-pr-tracking-toggle")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PR Polling Interval")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "How often to check for PR updates across all panes (min 15s). Uses a single batched GraphQL request per cycle — the rate limit auto-adjusts at high pane counts."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "30 seconds")
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                TextField(
                                    "",
                                    text: Binding(
                                        get: { String(appSettings.prPollingIntervalSeconds) },
                                        set: { newValue in
                                            if let parsed = Int(newValue) {
                                                appSettings.prPollingIntervalSeconds = max(15, parsed)
                                                SettingsPersistence.savePRPollingSettings(appSettings: appSettings)
                                            }
                                        }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 72)
                                .accessibilityIdentifier("settings-pr-polling-interval-field")
                                Text("seconds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Request Timeout")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Cancel the in-flight request and wait for the next cycle if it takes longer than this (min 5s)."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "15 seconds")
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                TextField(
                                    "",
                                    text: Binding(
                                        get: { String(appSettings.prRequestTimeoutSeconds) },
                                        set: { newValue in
                                            if let parsed = Int(newValue) {
                                                appSettings.prRequestTimeoutSeconds = max(5, parsed)
                                                SettingsPersistence.savePRPollingSettings(appSettings: appSettings)
                                            }
                                        }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 72)
                                .accessibilityIdentifier("settings-pr-request-timeout-field")
                                Text("seconds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Background Refresh")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Keep checking for PR updates while the app is in the background at a reduced rate. Disable to pause all polling when the app is not focused."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Background Refresh", isOn: $appSettings.prBackgroundRefreshEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .onChange(of: appSettings.prBackgroundRefreshEnabled) {
                                    SettingsPersistence.savePRPollingSettings(appSettings: appSettings)
                                }
                                .accessibilityIdentifier("settings-pr-background-refresh-toggle")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Background Polling Interval")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "How often to check for PR updates while the app is in the background (min 15s)."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                DefaultValueLabel(value: "60 seconds")
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                TextField(
                                    "",
                                    text: Binding(
                                        get: { String(appSettings.prBackgroundPollingIntervalSeconds) },
                                        set: { newValue in
                                            if let parsed = Int(newValue) {
                                                appSettings.prBackgroundPollingIntervalSeconds = max(15, parsed)
                                                SettingsPersistence.savePRPollingSettings(appSettings: appSettings)
                                            }
                                        }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 72)
                                .accessibilityIdentifier("settings-pr-background-interval-field")
                                Text("seconds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .opacity(appSettings.prBackgroundRefreshEnabled ? 1 : 0.4)
                        .disabled(!appSettings.prBackgroundRefreshEnabled)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                StatusLineConfigLayoutEditor(
                    config: $appSettings.statusLineConfig,
                    filterCLI: nil,
                    phases: .rows,
                    onPersist: {
                        SettingsPersistence.saveStatusLine(appSettings: appSettings)
                    })
            }
            .padding(20)
        }
    }
}

private struct EnvVarOptionRow: View {
    @Binding var option: EnvVarConfig
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.id)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("Show", isOn: $option.isAvailable)
                        .toggleStyle(.checkbox)
                        .onChange(of: option.isAvailable) {
                            if !option.isAvailable {
                                option.isDefaultEnabled = false
                            }
                            onChange()
                        }
                    Toggle("Default on", isOn: $option.isDefaultEnabled)
                        .toggleStyle(.checkbox)
                        .disabled(!option.isAvailable)
                        .onChange(of: option.isDefaultEnabled) { onChange() }
                }
            }
            if option.isAvailable {
                HStack(spacing: 8) {
                    Text("Default value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Value", text: $option.defaultValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .onChange(of: option.defaultValue) { onChange() }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CustomEnvVarOptionRow: View {
    @Binding var option: EnvVarConfig
    let onChange: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(option.id)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("Show", isOn: $option.isAvailable)
                        .toggleStyle(.checkbox)
                        .onChange(of: option.isAvailable) {
                            if !option.isAvailable {
                                option.isDefaultEnabled = false
                            }
                            onChange()
                        }
                    Toggle("Default on", isOn: $option.isDefaultEnabled)
                        .toggleStyle(.checkbox)
                        .disabled(!option.isAvailable)
                        .onChange(of: option.isDefaultEnabled) { onChange() }
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 8)
            }
            if option.isAvailable {
                HStack(spacing: 8) {
                    Text("Default value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Value", text: $option.defaultValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .onChange(of: option.defaultValue) { onChange() }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct AddCustomEnvVarSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingIDs: [String]
    let onAdd: (String) -> Void

    @State private var varName = ""

    private var isValid: Bool {
        let trimmed = varName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !existingIDs.contains(trimmed)
            && trimmed.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Custom Env Var")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Variable Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("MY_CUSTOM_VAR", text: $varName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { if isValid { submit() } }
                if !varName.isEmpty && existingIDs.contains(varName) {
                    Text("An environment variable with this name already exists.")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !varName.isEmpty && !isValid {
                    Text(
                        "Variable name must start with a letter or underscore and contain only letters, digits, or underscores."
                    )
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func submit() {
        guard isValid else { return }
        onAdd(varName.trimmingCharacters(in: .whitespaces))
        dismiss()
    }
}

private struct AddCustomFlagSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingIDs: [String]
    let onAdd: (String, Bool) -> Void

    @State private var flagName = ""
    @State private var isString = false

    private var isValid: Bool {
        !flagName.isEmpty && flagName.hasPrefix("--") && !existingIDs.contains(flagName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Custom Flag")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Flag Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("--my-flag", text: $flagName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { if isValid { submit() } }
                if !flagName.isEmpty && !flagName.hasPrefix("--") {
                    Text("Flag name must start with \"--\".")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !flagName.isEmpty && existingIDs.contains(flagName) {
                    Text("A flag with this name already exists.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Flag Type")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Flag Type", selection: $isString) {
                    Text("Boolean").tag(false)
                    Text("Text").tag(true)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private func submit() {
        guard isValid else { return }
        onAdd(flagName, isString)
        dismiss()
    }
}

private struct NotificationsContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Configure notification behavior for pane alerts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("macOS")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Banner Notifications")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Show a system notification when a background pane rings the bell. Requires permission in System Settings."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Banner Notifications", isOn: $appSettings.isMacOSBannerNotificationsEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-macos-banner-notifications-toggle")
                                .onChange(of: appSettings.isMacOSBannerNotificationsEnabled) {
                                    SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                                    if appSettings.debugLoggingEnabled {
                                        DebugLogger.shared.logNotificationEnvironment(
                                            macOSBannerNotificationsEnabled: appSettings.isMacOSBannerNotificationsEnabled
                                        )
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sticky Notifications")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Clear all macOS notifications when Agent Session Manager is focused. For banners to stay on screen until dismissed, set the notification style to \"Alerts\" in System Settings → Notifications."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                Button("Open Notification Settings") {
                                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
                                    NSWorkspace.shared.open(url)
                                }
                                .font(.caption)
                                .buttonStyle(.link)
                            }
                            Spacer()
                            Toggle("Sticky Notifications", isOn: $appSettings.isStickyNotificationsEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-sticky-notifications-toggle")
                                .onChange(of: appSettings.isStickyNotificationsEnabled) {
                                    SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Claude Code")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notification hook for attention")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Merge Claude’s Notification hook into each pane’s --settings so permission prompts and other notifies can trigger the same in‑app alerts as a terminal bell, even when no BEL or OSC 777 is sent."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle(
                                "Notification hook for attention",
                                isOn: $appSettings.isClaudeNotificationHookAttentionEnabled
                            )
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .accessibilityIdentifier("settings-claude-notification-hook-toggle")
                            .onChange(of: appSettings.isClaudeNotificationHookAttentionEnabled) {
                                SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                                NotificationCenter.default.post(
                                    name: .agentSessionManagerClaudeHookAttentionSettingChanged, object: nil)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Cursor")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Stop hook for attention")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Install a Cursor stop hook so the app is notified when the agent finishes a turn (plan ready, task complete, etc.)."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle(
                                "Stop hook for attention",
                                isOn: $appSettings.isCursorNotificationHookAttentionEnabled
                            )
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .accessibilityIdentifier("settings-cursor-notification-hook-toggle")
                            .onChange(of: appSettings.isCursorNotificationHookAttentionEnabled) {
                                SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sidebar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sidebar Position")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Which side the notification sidebar appears on.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("Sidebar Position", selection: $appSettings.notificationSidebarSide) {
                                ForEach(SidebarSide.allCases, id: \.self) { side in
                                    Text(side.displayName).tag(side)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 120)
                            .accessibilityIdentifier("settings-sidebar-side")
                            .onChange(of: appSettings.notificationSidebarSide) {
                                SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Always Show Notifications Bar")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Keep the notifications sidebar visible even when there are no notifications.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Always Show Notifications Bar", isOn: $appSettings.alwaysShowNotificationsSidebar)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-always-show-notifications-bar-toggle")
                                .onChange(of: appSettings.alwaysShowNotificationsSidebar) {
                                    SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Priority")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Priority Notifications")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(
                                    "Allow panes to be marked as priority. Priority notifications appear at the top of the sidebar."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Priority Notifications", isOn: $appSettings.isPriorityNotificationsEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-priority-notifications-toggle")
                                .onChange(of: appSettings.isPriorityNotificationsEnabled) {
                                    SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("GitHub PR")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PR Merged Notifications")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Show a sidebar notification and macOS banner when a tracked PR is merged.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("PR Merged Notifications", isOn: $appSettings.isPRMergedNotificationsEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-pr-merged-notifications-toggle")
                                .onChange(of: appSettings.isPRMergedNotificationsEnabled) {
                                    SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
    }
}
