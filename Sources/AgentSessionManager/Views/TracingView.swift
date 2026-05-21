import AppKit
import SwiftUI

struct TracingView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Configure OpenTelemetry span output.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tracing")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable Tracing")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("Emit OpenTelemetry spans for app events.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Enable Tracing", isOn: $appSettings.tracingEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .accessibilityIdentifier("settings-tracing-enabled-toggle")
                                .onChange(of: appSettings.tracingEnabled) {
                                    SettingsPersistence.saveTracingSettings(appSettings: appSettings)
                                    TracingService.shared.configure(from: appSettings)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        if appSettings.tracingEnabled {
                            Divider().padding(.leading, 16)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Output")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                    Text("Where to write spans.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                            Divider().padding(.leading, 16)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Dashboard Buffer")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                    Text("Max spans kept in memory for the in-app dashboard.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
                }

                if appSettings.tracingEnabled && appSettings.tracingOutputTarget == .file {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("File")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("File Path")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                    Text("Leave empty to use the default path in Application Support.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Default: \(appSettings.resolvedTracingFileURL.path)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .font(.system(.caption2, design: .monospaced))
                                }
                                Spacer()
                                TextField("", text: $appSettings.tracingFilePath)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 200)
                                    .onChange(of: appSettings.tracingFilePath) {
                                        SettingsPersistence.saveTracingSettings(appSettings: appSettings)
                                        TracingService.shared.configure(from: appSettings)
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                            Divider().padding(.leading, 16)

                            HStack {
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
                                Spacer()
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
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                            Divider().padding(.leading, 16)

                            HStack {
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
                                Spacer()
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
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
                    }
                }

                Text("Spans are written in OpenTelemetry JSON-Lines format. Use `jq` or an OTel viewer to inspect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(24)
        }
    }
}
