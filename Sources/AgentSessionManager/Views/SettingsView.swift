import SwiftUI

struct SettingsView: View {
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
        .frame(width: 560, height: 580)
        .sheet(isPresented: $showAddCustomFlagSheet) {
            AddCustomFlagSheet { id, isString in
                appSettings.cliOptions.append(CLIOptionConfig.makeUserAdded(id: id, isString: isString))
                SettingsPersistence.save(appSettings: appSettings)
            }
        }
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
