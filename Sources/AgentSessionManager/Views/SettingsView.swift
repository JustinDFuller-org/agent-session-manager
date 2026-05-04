import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        TabView {
            CLIOptionsContent(
                options: Binding(
                    get: { appSettings.cliOptions },
                    set: { appSettings.cliOptions = $0 }
                ),
                onSave: { SettingsPersistence.save(appSettings: appSettings) },
                customFlagFooter: "Custom flags are user-defined and may not be recognized by all Claude CLI versions."
            )
            .tabItem { Label("Claude Code", systemImage: "terminal") }
            CLIOptionsContent(
                options: Binding(
                    get: { appSettings.codexCliOptions },
                    set: { appSettings.codexCliOptions = $0 }
                ),
                onSave: { SettingsPersistence.saveCodexOptions(appSettings: appSettings) },
                customFlagFooter: "Custom flags are user-defined and may not be recognized by all Codex CLI versions."
            )
            .tabItem { Label("Codex", systemImage: "cpu") }
            KeyboardShortcutsContent()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            StatusLineContent()
                .environment(appSettings)
                .tabItem { Label("Status Line", systemImage: "chart.bar") }
        }
        .frame(width: 560, height: 580)
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
                Text("Configure which CLI options appear when creating a new pane. Options marked as default will be pre-checked in the New Pane dialog.")
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

    var body: some View {
        Form {
            Section {
                Text("Customize keyboard shortcuts. Each shortcut uses ⌘ plus the key you specify. Changes take effect immediately.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Shortcuts") {
                KeyBindingRow(label: "New Tab", description: "Open the New Tab sheet", modifier: "⌘", key: $newTabKey)
                KeyBindingRow(label: "New Pane in Current Tab", description: "Open the New Pane sheet", modifier: "⌘", key: $newPaneKey)
                KeyBindingRow(label: "Close Active Pane", description: "Close the focused pane", modifier: "⌘", key: $closePaneKey)
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
                Text("Configure the info panel shown at the bottom of each pane. Items are populated from Claude session data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                        Button(item.label) {
                            appSettings.statusLineConfig.rows[rowIndex].items.append(item)
                            SettingsPersistence.saveStatusLine(appSettings: appSettings)
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
        case "cost": return "Total session cost in USD"
        case "context": return "Context window usage (with progress bar)"
        case "effort": return "Effort level"
        case "thinking": return "Whether extended thinking is on or off"
        case "vimMode": return "Vim editor mode"
        case "agentName": return "Agent name"
        case "sessionName": return "Session name"
        case "worktreeBranch": return "Git branch for the worktree"
        case "gitWorktree": return "Git worktree path"
        case "linesAdded": return "Total lines added this session"
        case "linesRemoved": return "Total lines removed this session"
        case "duration": return "Total session duration"
        case "contextRemaining": return "Context window remaining percentage"
        case "inputTokens": return "Total input tokens used"
        case "outputTokens": return "Total output tokens used"
        case "rate5h": return "5-hour rate limit usage (with progress bar)"
        case "rate7d": return "7-day rate limit usage (with progress bar)"
        case "rate5hReset": return "Time until 5-hour rate limit resets"
        case "rate7dReset": return "Time until 7-day rate limit resets"
        case "version": return "Claude CLI version"
        case "outputStyle": return "Output style name"
        case "exceeds200k": return "Warning when context exceeds 200k tokens"
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
        !flagName.isEmpty &&
        flagName.hasPrefix("--") &&
        !existingIDs.contains(flagName)
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
