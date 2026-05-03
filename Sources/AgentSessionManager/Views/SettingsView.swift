import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings

    private var enabledOptions: [CLIOptionConfig] {
        appSettings.cliOptions.filter { $0.isAvailable }.sorted { $0.id < $1.id }
    }

    private var disabledOptions: [CLIOptionConfig] {
        appSettings.cliOptions.filter { !$0.isAvailable }.sorted { $0.id < $1.id }
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
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 520)
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
