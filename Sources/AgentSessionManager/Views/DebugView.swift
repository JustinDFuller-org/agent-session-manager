import SwiftUI

struct DebugView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Section("Debug") {
                SettingRow(
                    title: "Enable Debug Mode",
                    description: "Write OpenTelemetry traces and invariant violations to bounded JSONL files.",
                    defaultValue: "Off"
                ) {
                    Toggle("Enable Debug Mode", isOn: $appSettings.debugModeEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-debug-mode-toggle")
                        .onChange(of: appSettings.debugModeEnabled) {
                            SettingsPersistence.save(
                                SettingsPersistence.DebugSettings(
                                    schemaVersion: 1, enabled: appSettings.debugModeEnabled),
                                to: "debug-settings.json")
                            TracingService.shared.configure(from: appSettings)
                            InvariantReporter.shared.configure(from: appSettings)
                        }
                }
            }
            Section("Dashboards") {
                Button("Open Trace Dashboard") {
                    openWindow(id: "trace-dashboard")
                }
                .accessibilityIdentifier("settings-open-trace-dashboard-button")
                Button("Open Invariant Dashboard") {
                    openWindow(id: "invariant-dashboard")
                }
                .accessibilityIdentifier("settings-open-invariant-dashboard-button")
            }
            Section {
                Text("Debug files use fixed 10 MB limits under Application Support.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
