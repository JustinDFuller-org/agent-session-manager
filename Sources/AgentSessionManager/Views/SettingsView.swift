import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case profiles
    case tools
    case cliOptions = "cli-options"
    case worktrees
    case shortcuts
    case statusLine = "status-line"
    case notifications
    case tracing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .profiles: "Profiles"
        case .tools: "Tools"
        case .cliOptions: "CLI Options"
        case .worktrees: "Worktrees"
        case .shortcuts: "Shortcuts"
        case .statusLine: "Status Line"
        case .notifications: "Notifications"
        case .tracing: "Tracing"
        }
    }

    var icon: String {
        switch self {
        case .general: "gear"
        case .profiles: "person.crop.rectangle.stack"
        case .tools: "wrench.and.screwdriver"
        case .cliOptions: "terminal"
        case .worktrees: "folder.badge.gearshape"
        case .shortcuts: "keyboard"
        case .statusLine: "chart.bar"
        case .notifications: "bell"
        case .tracing: "waveform"
        }
    }
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
                    .accessibilityIdentifier("settings-sidebar-\(section.rawValue)")
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 28)
            }
        } detail: {
            detailView(for: selection)
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Text(selection.title)
                            .font(.title.bold())
                        Spacer()
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 20)
                }
        }
        .frame(minWidth: 720, idealWidth: 820, minHeight: 520, idealHeight: 600)
    }

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralContent()
                .environment(appSettings)
        case .profiles:
            ProfilesContent()
                .environment(appSettings)
        case .tools:
            ToolsContent()
                .environment(appSettings)
        case .cliOptions:
            UnifiedCLIOptionsContent()
                .environment(appSettings)
        case .worktrees:
            WorktreesContent()
                .environment(appSettings)
        case .shortcuts:
            KeyboardShortcutsContent()
        case .statusLine:
            StatusLineContent()
                .environment(appSettings)
        case .notifications:
            NotificationsContent()
                .environment(appSettings)
        case .tracing:
            TracingView()
                .environment(appSettings)
        }
    }
}

struct DefaultValueLabel: View {
    let value: String

    var body: some View {
        Text("Default: \(value)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    let description: String
    var defaultValue: String?
    @ViewBuilder var control: () -> Control

    var body: some View {
        LabeledContent {
            control()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let defaultValue {
                    DefaultValueLabel(value: defaultValue)
                }
            }
        }
    }
}

private struct GeneralContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Section("Git") {
                SettingRow(
                    title: "Default Branch",
                    description: "Automatically fetch and create worktrees from a default branch."
                ) {
                    Toggle("Default Branch", isOn: $appSettings.isDefaultBranchEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-default-branch-toggle")
                        .onChange(of: appSettings.isDefaultBranchEnabled) {
                            SettingsPersistence.saveDefaultBranch(appSettings: appSettings)
                        }
                }
                if appSettings.isDefaultBranchEnabled {
                    SettingRow(
                        title: "Branch Name",
                        description: "Branch used as the base when creating new worktrees.",
                        defaultValue: "main"
                    ) {
                        TextField("", text: $appSettings.defaultBranch)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 120)
                            .accessibilityIdentifier("settings-default-branch-field")
                            .onChange(of: appSettings.defaultBranch) {
                                SettingsPersistence.saveDefaultBranch(appSettings: appSettings)
                            }
                    }
                }
            }
            Section("Sessions") {
                SettingRow(
                    title: "Continue on Restart",
                    description: "Resume the last conversation when Claude panes reopen after a restart."
                ) {
                    Toggle("Continue on Restart", isOn: $appSettings.continueOnRestart)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-continue-on-restart-toggle")
                        .onChange(of: appSettings.continueOnRestart) {
                            SettingsPersistence.saveRestartSettings(appSettings: appSettings)
                        }
                }
                SettingRow(
                    title: "Auto Session Name",
                    description:
                        "Passes --name <tab>/<pane> to Claude so sessions appear by name in claude resume "
                        + "and the terminal title. Skipped if --name is set manually in CLI Options."
                ) {
                    Toggle("Auto Session Name", isOn: $appSettings.autoSetSessionName)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-auto-session-name-toggle")
                        .onChange(of: appSettings.autoSetSessionName) {
                            SettingsPersistence.saveSessionNameSettings(appSettings: appSettings)
                        }
                }
            }
            Section("Terminal") {
                SettingRow(
                    title: "When Process Exits",
                    description: appSettings.exitBehavior.description,
                    defaultValue: "Show Prompt"
                ) {
                    Picker("When Process Exits", selection: $appSettings.exitBehavior) {
                        ForEach(ExitBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("settings-exit-behavior-picker")
                    .onChange(of: appSettings.exitBehavior) {
                        SettingsPersistence.saveExitBehavior(appSettings: appSettings)
                    }
                }
                SettingRow(
                    title: "Scrollback Lines",
                    description: "Number of lines kept in the terminal scroll buffer (100–1,000,000).",
                    defaultValue: "500"
                ) {
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
            }
        }
        .formStyle(.grouped)
    }
}

private struct ToolsContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        Form {
            Section("Available Tools") {
                ForEach(CLIType.allCases, id: \.self) { tool in
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
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct WorktreesContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Section("Created Worktrees") {
                SettingRow(
                    title: "Worktree Cleanup",
                    description: appSettings.worktreeCleanupBehavior.description,
                    defaultValue: "Ask"
                ) {
                    Picker("Worktree Cleanup", selection: $appSettings.worktreeCleanupBehavior) {
                        ForEach(WorktreeCleanupBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("settings-worktree-cleanup-picker")
                    .onChange(of: appSettings.worktreeCleanupBehavior) {
                        SettingsPersistence.saveWorktreeCleanup(appSettings: appSettings)
                    }
                }
                SettingRow(
                    title: "Base Ref",
                    description: appSettings.worktreeBaseRef.description,
                    defaultValue: "Fresh"
                ) {
                    Picker("Base Ref", selection: $appSettings.worktreeBaseRef) {
                        ForEach(WorktreeBaseRef.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("settings-worktree-base-ref-picker")
                    .onChange(of: appSettings.worktreeBaseRef) {
                        SettingsPersistence.saveWorktreeBaseRef(appSettings: appSettings)
                    }
                }
            }
            Section("Existing Worktrees") {
                SettingRow(
                    title: "Manage Existing Worktrees",
                    description: appSettings.existingWorktreeManagement.description,
                    defaultValue: "Ask"
                ) {
                    Picker("Manage Existing", selection: $appSettings.existingWorktreeManagement) {
                        ForEach(ExistingWorktreeManagement.allCases, id: \.self) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("settings-existing-worktree-management-picker")
                    .onChange(of: appSettings.existingWorktreeManagement) {
                        SettingsPersistence.saveExistingWorktreeManagement(appSettings: appSettings)
                    }
                }
            }
        }
        .formStyle(.grouped)
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
        Form {
            if !enabledOptions.isEmpty {
                Section("Enabled") {
                    ForEach(enabledOptions, id: \.id) { option in
                        let optIndex = options.firstIndex(where: { $0.id == option.id })!
                        CLIOptionRow(option: $options[optIndex], onChange: onSave)
                    }
                }
            }
            Section("Not Enabled") {
                ForEach(disabledOptions, id: \.id) { option in
                    let optIndex = options.firstIndex(where: { $0.id == option.id })!
                    CLIOptionRow(option: $options[optIndex], onChange: onSave)
                }
            }
            Section(
                header: Text("Custom Options"),
                footer: Text(customFlagFooter).font(.caption).foregroundStyle(.secondary)
            ) {
                ForEach(customOptions, id: \.id) { option in
                    let optIndex = options.firstIndex(where: { $0.id == option.id })!
                    CustomCLIOptionRow(
                        option: $options[optIndex],
                        onChange: onSave,
                        onDelete: {
                            options.removeAll { $0.id == option.id }
                            onSave()
                        }
                    )
                }
                Button {
                    showAddCustomFlagSheet = true
                } label: {
                    Label("Add Custom Flag", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            if let envBinding = envVarOptions, let envSave = onEnvVarSave {
                EnvVarSections(
                    options: envBinding,
                    onSave: envSave,
                    showAddSheet: $showAddCustomEnvVarSheet
                )
            }
        }
        .formStyle(.grouped)
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
        Group {
            Section("Environment Variables") {
                Text(
                    "Configure which environment variables are set when launching Claude Code. Variables marked as default will be pre-enabled with their default value in the New Pane dialog."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if !enabledOptions.isEmpty {
                Section("Enabled Env Vars") {
                    ForEach(enabledOptions, id: \.id) { option in
                        let optIndex = options.firstIndex(where: { $0.id == option.id })!
                        EnvVarOptionRow(option: $options[optIndex], onChange: onSave)
                    }
                }
            }
            Section("Not Enabled Env Vars") {
                ForEach(disabledOptions, id: \.id) { option in
                    let optIndex = options.firstIndex(where: { $0.id == option.id })!
                    EnvVarOptionRow(option: $options[optIndex], onChange: onSave)
                }
            }
            Section(
                header: Text("Custom Env Vars"),
                footer: Text("Custom environment variables are passed to the Claude Code process.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            ) {
                ForEach(customOptions, id: \.id) { option in
                    let optIndex = options.firstIndex(where: { $0.id == option.id })!
                    CustomEnvVarOptionRow(
                        option: $options[optIndex],
                        onChange: onSave,
                        onDelete: {
                            options.removeAll { $0.id == option.id }
                            onSave()
                        }
                    )
                }
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Custom Env Var", systemImage: "plus")
                }
                .buttonStyle(.borderless)
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
        Form {
            Section("Shortcuts") {
                KeyBindingRow(
                    label: "New Tab", description: "Open the New Tab sheet", modifier: "⌘",
                    key: $newTabKey)
                KeyBindingRow(
                    label: "New Pane in Current Tab", description: "Open the New Pane sheet",
                    modifier: "⌘", key: $newPaneKey)
                KeyBindingRow(
                    label: "Close Active Pane", description: "Close the focused pane", modifier: "⌘",
                    key: $closePaneKey)
                KeyBindingRow(
                    label: "Close Active Tab", description: "Close the current tab", modifier: "⌘",
                    key: $closeTabKey)
                KeyBindingRow(
                    label: "Open Shell Here",
                    description: "Open a new plain shell pane in the same working directory",
                    modifier: "⌘⇧", key: $openShellHereKey)
                KeyBindingRow(
                    label: "Refresh Active Pane",
                    description: "Restart pane with fresh environment",
                    modifier: "⌘", key: $refreshPaneKey)
            }
            Section(
                header: Text("Fixed Shortcuts"),
                footer: Text("Tab switching shortcuts are not configurable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            ) {
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
            }
        }
        .formStyle(.grouped)
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
        .padding(.vertical, 4)
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
                    HStack(spacing: 4) {
                        Text("Show")
                            .font(.caption)
                        Toggle("Show", isOn: $option.isAvailable)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .onChange(of: option.isAvailable) {
                                if !option.isAvailable {
                                    option.isDefaultEnabled = false
                                }
                                onChange()
                            }
                    }
                    HStack(spacing: 4) {
                        Text("Default on")
                            .font(.caption)
                        Toggle("Default on", isOn: $option.isDefaultEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .disabled(!option.isAvailable)
                            .onChange(of: option.isDefaultEnabled) { onChange() }
                    }
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
                    HStack(spacing: 4) {
                        Text("Show")
                            .font(.caption)
                        Toggle("Show", isOn: $option.isAvailable)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .onChange(of: option.isAvailable) {
                                if !option.isAvailable {
                                    option.isDefaultEnabled = false
                                }
                                onChange()
                            }
                    }
                    HStack(spacing: 4) {
                        Text("Default on")
                            .font(.caption)
                        Toggle("Default on", isOn: $option.isDefaultEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .disabled(!option.isAvailable)
                            .onChange(of: option.isDefaultEnabled) { onChange() }
                    }
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
