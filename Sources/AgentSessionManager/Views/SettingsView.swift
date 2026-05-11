import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        TabView {
            GeneralContent()
                .environment(appSettings)
                .tabItem { Label("General", systemImage: "gear") }
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
        .frame(width: 560, height: 580)
    }
}

private struct GeneralContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        ScrollView {
            Form {
                Section {
                    Text("Configure general app behavior.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Git") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
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
                    .padding(.vertical, 2)

                    if appSettings.isDefaultBranchEnabled {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Branch Name")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Branch used as the base when creating new worktrees.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            TextField("e.g. main", text: $appSettings.defaultBranch)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 120)
                                .accessibilityIdentifier("settings-default-branch-field")
                                .onChange(of: appSettings.defaultBranch) {
                                    SettingsPersistence.saveDefaultBranch(appSettings: appSettings)
                                }
                        }
                        .padding(.vertical, 2)
                    }
                }
                Section("Sessions") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
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
                    .padding(.vertical, 2)
                }
                Section("Terminal") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scrollback Lines")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Text("Number of lines kept in the terminal scroll buffer (100–1,000,000).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField(
                            "500",
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
                    .padding(.vertical, 2)
                }
                Section("Debug") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
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
                    .padding(.vertical, 2)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trace file path")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Text("Leave empty for the default file under Application Support. ~ is expanded.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField("Default if empty", text: $appSettings.debugLogFilePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(minWidth: 220)
                            .accessibilityIdentifier("settings-debug-log-file-path")
                            .onChange(of: appSettings.debugLogFilePath) {
                                DebugLogger.shared.syncFromAppSettings(appSettings)
                                SettingsPersistence.saveDebugSettings(appSettings: appSettings)
                            }
                    }
                    .padding(.vertical, 2)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Max trace file size")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Text("When exceeded, older bytes are removed from the start of the file.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    .padding(.vertical, 2)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
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
                    .padding(.vertical, 2)
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct ToolsContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        Form {
            Section {
                Text(
                    "Select which AI tools are available when creating a new pane. Only active tools appear in the New Pane sheet."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Section("Available Tools") {
                ForEach(CLIType.allCases, id: \.self) { tool in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
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
                    .padding(.vertical, 2)
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
            Section {
                Text("Configure worktree management behavior.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Created Worktrees") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Worktree Cleanup")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        Text(appSettings.worktreeCleanupBehavior.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                .padding(.vertical, 2)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Base Ref")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        Text(appSettings.worktreeBaseRef.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                .padding(.vertical, 2)
            }

            Section("Existing Worktrees") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Existing Worktrees")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        Text(appSettings.existingWorktreeManagement.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                .padding(.vertical, 2)
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
                    customFlagFooter: "Custom flags may not be recognized by all Claude CLI versions."
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
            }
        }
    }
}

private struct CLIOptionsContent: View {
    @Binding var options: [CLIOptionConfig]
    let onSave: () -> Void
    let customFlagFooter: String
    @State private var showAddCustomFlagSheet = false

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
            Section {
                Text(
                    "Configure which CLI options appear when creating a new pane. Options marked as default will be pre-checked in the New Pane dialog."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            if !enabledOptions.isEmpty {
                Section("Enabled") {
                    ForEach(enabledOptions, id: \.id) { option in
                        let index = options.firstIndex(where: { $0.id == option.id })!
                        CLIOptionRow(option: $options[index], onChange: onSave)
                    }
                }
            }
            Section("Not Enabled") {
                ForEach(disabledOptions, id: \.id) { option in
                    let index = options.firstIndex(where: { $0.id == option.id })!
                    CLIOptionRow(option: $options[index], onChange: onSave)
                }
            }
            Section {
                ForEach(customOptions, id: \.id) { option in
                    let index = options.firstIndex(where: { $0.id == option.id })!
                    CustomCLIOptionRow(
                        option: $options[index],
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
            } header: {
                Text("Custom Options")
            } footer: {
                Text(customFlagFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddCustomFlagSheet) {
            AddCustomFlagSheet(existingIDs: options.map(\.id)) { id, isString in
                options.append(CLIOptionConfig.makeUserAdded(id: id, isString: isString))
                onSave()
            }
        }
    }
}

private struct KeyboardShortcutsContent: View {
    @AppStorage("keyBinding.newTabKey") var newTabKey = "t"
    @AppStorage("keyBinding.newPaneKey") var newPaneKey = "p"
    @AppStorage("keyBinding.closePaneKey") var closePaneKey = "w"
    @AppStorage("keyBinding.closeTabKey") var closeTabKey = "k"

    var body: some View {
        Form {
            Section {
                Text(
                    "Customize keyboard shortcuts. Each shortcut uses ⌘ plus the key you specify. Changes take effect immediately."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Section("Shortcuts") {
                KeyBindingRow(label: "New Tab", description: "Open the New Tab sheet", modifier: "⌘", key: $newTabKey)
                KeyBindingRow(
                    label: "New Pane in Current Tab", description: "Open the New Pane sheet", modifier: "⌘",
                    key: $newPaneKey)
                KeyBindingRow(
                    label: "Close Active Pane", description: "Close the focused pane", modifier: "⌘", key: $closePaneKey
                )
                KeyBindingRow(
                    label: "Close Active Tab", description: "Close the current tab", modifier: "⌘", key: $closeTabKey)
            }
            Section {
                HStack {
                    Text("⌘1 – ⌘9")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    Spacer()
                    Text("Switch to tab by index")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            } header: {
                Text("Fixed Shortcuts")
            } footer: {
                Text("Tab switching shortcuts are not configurable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 4) {
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
        .padding(.vertical, 2)
    }
}

private struct CLIOptionRow: View {
    @Binding var option: CLIOptionConfig
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, 2)
    }
}

private struct CustomCLIOptionRow: View {
    @Binding var option: CLIOptionConfig
    let onChange: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(option.id)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        Text(option.customIsStringType ? "text" : "boolean")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
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
        .padding(.vertical, 2)
    }
}

private struct StatusLineContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Section {
                Text(
                    "Configure the info panel shown at the bottom of each pane. Items marked \"Claude only\" require Claude Code's statusLine hook. Items marked \"OpenCode only\" are populated via the OpenCode HTTP API. All other items work with any tool via git and process data."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings-status-line-description")
            }
            Section("Display") {
                Picker("Chip style", selection: $appSettings.statusLineConfig.chipLabelStyle) {
                    ForEach(ChipLabelStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .onChange(of: appSettings.statusLineConfig.chipLabelStyle) {
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                }
                Picker("Item alignment", selection: $appSettings.statusLineConfig.rowAlignment) {
                    ForEach(RowAlignment.allCases, id: \.self) { alignment in
                        Text(alignment.displayName).tag(alignment)
                    }
                }
                .onChange(of: appSettings.statusLineConfig.rowAlignment) {
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                }
            }
            Section("GitHub PR Tracking") {
                Toggle(isOn: $appSettings.githubPRTrackingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Track pull requests")
                        Text(
                            "Detects the PR for the current git branch and shows its status in the status line. Requires the GitHub CLI (gh) installed and authenticated."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .onChange(of: appSettings.githubPRTrackingEnabled) {
                    SettingsPersistence.savePRTracking(appSettings: appSettings)
                }
                .accessibilityIdentifier("settings-pr-tracking-toggle")
            }
            ForEach(appSettings.statusLineConfig.rows.indices, id: \.self) { rowIndex in
                rowSection(rowIndex: rowIndex, appSettings: appSettings)
            }
            Section {
                Button {
                    appSettings.statusLineConfig.rows.append(StatusLineRow())
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                } label: {
                    Label("Add Row", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func availabilityBadge(for availability: ToolAvailability) -> some View {
        switch availability {
        case .claudeOnly:
            Text("Claude only")
                .font(.caption2)
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.1)))
        case .opencodeOnly:
            Text("OpenCode only")
                .font(.caption2)
                .foregroundStyle(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.purple.opacity(0.1)))
        case .claudeOrOpencode:
            Text("Claude + OpenCode")
                .font(.caption2)
                .foregroundStyle(.indigo)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.indigo.opacity(0.1)))
        case .all:
            Text("All tools")
                .font(.caption2)
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.1)))
        }
    }

    @ViewBuilder
    private func rowSection(rowIndex: Int, appSettings: AppSettings) -> some View {
        @Bindable var appSettings = appSettings
        let rowCount = appSettings.statusLineConfig.rows.count
        let available = StatusLineConfig.allItems.filter {
            !appSettings.statusLineConfig.usedItemIDs.contains($0.id)
        }
        Section {
            ForEach(appSettings.statusLineConfig.rows[rowIndex].items) { item in
                HStack {
                    Image(systemName: item.sfSymbol)
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
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
                        appSettings.statusLineConfig.rows[rowIndex].items.removeAll { $0.id == item.id }
                        SettingsPersistence.saveStatusLine(appSettings: appSettings)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 2)
            }
            .onMove { from, to in
                appSettings.statusLineConfig.rows[rowIndex].items.move(fromOffsets: from, toOffset: to)
                SettingsPersistence.saveStatusLine(appSettings: appSettings)
            }
            Menu {
                if available.isEmpty {
                    Text("All items are already used")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(available) { item in
                        Button {
                            appSettings.statusLineConfig.rows[rowIndex].items.append(item)
                            SettingsPersistence.saveStatusLine(appSettings: appSettings)
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
        } header: {
            HStack {
                Text("Row \(rowIndex + 1)")
                    .font(.headline)
                Spacer()
                Button {
                    appSettings.statusLineConfig.rows.swapAt(rowIndex, rowIndex - 1)
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(rowIndex == 0)
                Button {
                    appSettings.statusLineConfig.rows.swapAt(rowIndex, rowIndex + 1)
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(rowIndex == rowCount - 1)
                Button(role: .destructive) {
                    appSettings.statusLineConfig.rows.remove(at: rowIndex)
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
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
        default: return ""
        }
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
        Form {
            Section {
                Text("Configure notification behavior for pane alerts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("macOS") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Banner Notifications")
                            .font(.system(.body, design: .default))
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
                .padding(.vertical, 2)
            }
            Section("Claude Code") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notification hook for attention")
                            .font(.system(.body, design: .default))
                            .fontWeight(.medium)
                        Text(
                            "Merge Claude’s Notification hook into each pane’s --settings so permission prompts and other notifies can trigger the same in‑app alerts as a terminal bell, even when no BEL or OSC 777 is sent."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "Notification hook for attention", isOn: $appSettings.isClaudeNotificationHookAttentionEnabled
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
                .padding(.vertical, 2)
            }
            Section("Sidebar") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sidebar Position")
                            .font(.system(.body, design: .default))
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
                .padding(.vertical, 2)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Always Show Notifications Bar")
                            .font(.system(.body, design: .default))
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
                .padding(.vertical, 2)
            }
            Section("Priority") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Priority Notifications")
                            .font(.system(.body, design: .default))
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
                .padding(.vertical, 2)
            }
            Section("GitHub PR") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PR Merged Notifications")
                            .font(.system(.body, design: .default))
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
                .padding(.vertical, 2)
            }
        }
        .formStyle(.grouped)
    }
}
