import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        TabView {
            CLIOptionsContent()
                .environment(appSettings)
                .tabItem { Label("CLI Options", systemImage: "terminal") }
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
    @Environment(AppSettings.self) private var appSettings
    @State private var showAddCustomFlagSheet = false

    private var enabledOptions: [CLIOptionConfig] {
        appSettings.cliOptions.filter { $0.isAvailable && !$0.isUserAdded }.sorted { $0.id < $1.id }
    }

    private var disabledOptions: [CLIOptionConfig] {
        appSettings.cliOptions.filter { !$0.isAvailable && !$0.isUserAdded }.sorted { $0.id < $1.id }
    }

    private var customOptions: [CLIOptionConfig] {
        appSettings.cliOptions.filter(\.isUserAdded).sorted { $0.id < $1.id }
    }

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Section {
                Text("Configure which CLI options appear when creating a new pane. Options marked as default will be pre-checked in the New Pane dialog.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !enabledOptions.isEmpty {
                Section("Enabled") {
                    ForEach(enabledOptions, id: \.id) { option in
                        let index = appSettings.cliOptions.firstIndex(where: { $0.id == option.id })!
                        CLIOptionRow(option: $appSettings.cliOptions[index], onChange: {
                            SettingsPersistence.save(appSettings: appSettings)
                        })
                    }
                }
            }
            Section("Not Enabled") {
                ForEach(disabledOptions, id: \.id) { option in
                    let index = appSettings.cliOptions.firstIndex(where: { $0.id == option.id })!
                    CLIOptionRow(option: $appSettings.cliOptions[index], onChange: {
                        SettingsPersistence.save(appSettings: appSettings)
                    })
                }
            }
            Section {
                ForEach(customOptions, id: \.id) { option in
                    let index = appSettings.cliOptions.firstIndex(where: { $0.id == option.id })!
                    CustomCLIOptionRow(
                        option: $appSettings.cliOptions[index],
                        onChange: { SettingsPersistence.save(appSettings: appSettings) },
                        onDelete: {
                            appSettings.cliOptions.removeAll { $0.id == option.id }
                            SettingsPersistence.save(appSettings: appSettings)
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
                Text("Custom flags are user-defined and may not be recognized by all Claude CLI versions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddCustomFlagSheet) {
            AddCustomFlagSheet { id, isString in
                appSettings.cliOptions.append(CLIOptionConfig.makeUserAdded(id: id, isString: isString))
                SettingsPersistence.save(appSettings: appSettings)
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
                Text("Configure which status items appear at the bottom of each pane. Items are populated from the Claude session data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Items") {
                ForEach($appSettings.statusLineConfig.items) { $item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Text(itemDescription(for: item.id))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Visible", isOn: $item.isVisible)
                            .toggleStyle(.checkbox)
                            .onChange(of: item.isVisible) {
                                SettingsPersistence.saveStatusLine(appSettings: appSettings)
                            }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func itemDescription(for id: String) -> String {
        switch id {
        case "model": return "Claude model name, e.g. \"Opus\""
        case "worktree": return "Git worktree name"
        case "cost": return "Total session cost in USD"
        case "context": return "Context window usage percentage"
        case "rate5h": return "5-hour rate limit usage"
        case "rate7d": return "7-day rate limit usage"
        default: return ""
        }
    }
}

private struct AddCustomFlagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var appSettings

    let onAdd: (String, Bool) -> Void

    @State private var flagName = ""
    @State private var isString = false

    private var isValid: Bool {
        !flagName.isEmpty && !appSettings.cliOptions.contains(where: { $0.id == flagName })
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
                if !flagName.isEmpty && appSettings.cliOptions.contains(where: { $0.id == flagName }) {
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
