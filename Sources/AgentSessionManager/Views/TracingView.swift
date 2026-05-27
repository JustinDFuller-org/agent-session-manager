import AppKit
import SwiftUI

struct TracingView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Section("Tracing") {
                SettingRow(
                    title: "Enable Tracing",
                    description: "Emit OpenTelemetry spans for app events."
                ) {
                    Toggle("Enable Tracing", isOn: $appSettings.tracingEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-tracing-enabled-toggle")
                        .onChange(of: appSettings.tracingEnabled) {
                            SettingsPersistence.saveTracingSettings(appSettings: appSettings)
                            TracingService.shared.configure(from: appSettings)
                        }
                }
                if appSettings.tracingEnabled {
                    SettingRow(
                        title: "Output",
                        description: "Where to write spans."
                    ) {
                        Picker("Output", selection: $appSettings.tracingOutputTarget) {
                            ForEach(TracingOutputTarget.allCases, id: \.self) { target in
                                Text(target.displayName).tag(target)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                        .labelsHidden()
                        .onChange(of: appSettings.tracingOutputTarget) {
                            SettingsPersistence.saveTracingSettings(appSettings: appSettings)
                            TracingService.shared.configure(from: appSettings)
                        }
                    }
                    SettingRow(
                        title: "Dashboard Buffer",
                        description: "Max spans kept in memory for the in-app dashboard."
                    ) {
                        HStack(spacing: 4) {
                            TextField("", value: $appSettings.traceDashboardMaxSpans, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 72)
                                .accessibilityIdentifier("settings-tracing-dashboard-max-spans-field")
                                .onChange(of: appSettings.traceDashboardMaxSpans) {
                                    let clamped = max(1, appSettings.traceDashboardMaxSpans)
                                    appSettings.traceDashboardMaxSpans = clamped
                                    TraceStore.shared.maxSpans = clamped
                                    SettingsPersistence.saveTracingSettings(appSettings: appSettings)
                                }
                            Text("spans")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if appSettings.tracingEnabled && appSettings.tracingOutputTarget == .file {
                Section("File") {
                    LabeledContent {
                        TextField("", text: $appSettings.tracingFilePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 200)
                            .onChange(of: appSettings.tracingFilePath) {
                                SettingsPersistence.saveTracingSettings(appSettings: appSettings)
                                TracingService.shared.configure(from: appSettings)
                            }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("File Path")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Text("Leave empty to use the default path in Application Support.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Default: \(appSettings.resolvedTracingFileURL.path)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    LabeledContent {
                        HStack(spacing: 4) {
                            TextField("", value: $appSettings.tracingFileMaxSizeMegabytes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onChange(of: appSettings.tracingFileMaxSizeMegabytes) {
                                    SettingsPersistence.saveTracingSettings(appSettings: appSettings)
                                }
                            Text("MB")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max File Size")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Text("Older spans are trimmed when this limit is reached.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Default: 10 MB")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    LabeledContent {
                        HStack(spacing: 8) {
                            Button("Copy Path") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(
                                    appSettings.resolvedTracingFileURL.path,
                                    forType: .string
                                )
                            }
                            .buttonStyle(.bordered)
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([
                                    appSettings.resolvedTracingFileURL
                                ])
                            }
                            .buttonStyle(.bordered)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resolved Path")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Text(appSettings.resolvedTracingFileURL.path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            Section {
                Text(
                    "Spans are written in OpenTelemetry JSON-Lines format. Use `jq` or an OTel viewer to inspect."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
