import AppKit
import SwiftUI

/// Sheet reached from the ladybug: trace file path, snapshot capture, and bug-report shortcuts.
struct DebugLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var debug = DebugLogger.shared
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Debug Tracing")
                    .font(.headline)
                Spacer()
            }

            Text(
                "Telemetry is written only to the trace file below (not kept in memory). Use Reveal in Finder to inspect or attach it to a report. Review the file for secrets before sharing."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appSettings.resolvedDebugLogFileURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Button("Copy Path") {
                            let path = appSettings.resolvedDebugLogFileURL.path
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(path, forType: .string)
                        }
                        .accessibilityIdentifier("debug-log-copy-path-button")

                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([appSettings.resolvedDebugLogFileURL])
                        }
                        .accessibilityIdentifier("debug-log-reveal-button")
                    }
                }
                .padding(8)
            }

            HStack(spacing: 8) {
                Button("Capture Terminal Snapshots") {
                    for tab in appState.tabs {
                        for pane in tab.panes {
                            guard let content = pane.terminalController?.terminalContent,
                                !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            else { continue }
                            DebugLogger.shared.logTerminalContent(
                                paneName: pane.name,
                                content: content,
                                tabName: tab.name,
                                paneID: pane.id
                            )
                        }
                    }
                }
                .disabled(
                    appState.tabs.isEmpty
                        || (!(appSettings.debugLoggingEnabled && appSettings.debugLogIncludeTerminalContents)
                            && DebugLogger.shared.tracedPaneTerminalCaptureIDs.isEmpty)
                )
                .accessibilityIdentifier("debug-log-capture-button")

                Button("Truncate Trace File") {
                    debug.clear()
                }
                .accessibilityIdentifier("debug-log-clear-button")

                Spacer()

                Button("Report Bug…") {
                    DebugLogger.openBugReport(traceFilePath: appSettings.resolvedDebugLogFileURL.path)
                }
                .accessibilityIdentifier("debug-log-report-button")
            }

            Text(debugToolsFooter)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("debug-log-telemetry-footer")

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("debug-log-close-button")
            }
        }
        .padding(24)
        .frame(minWidth: 480, idealWidth: 560, minHeight: 320, idealHeight: 380)
    }

    private var debugToolsFooter: String {
        var parts: [String] = []
        parts.append("Global debug: \(appSettings.debugLoggingEnabled ? "on" : "off")")
        parts.append("terminal snapshots global: \(appSettings.debugLogIncludeTerminalContents ? "on" : "off")")
        parts.append("per-pane capture panes: \(DebugLogger.shared.tracedPaneTerminalCaptureIDs.count)")
        parts.append("traced panes (events): \(DebugLogger.shared.tracedPaneIDs.count)")
        parts.append(
            "max file: \(ByteCountFormatter.string(fromByteCount: Int64(appSettings.debugLogMaxFileBytes), countStyle: .file))"
        )
        return parts.joined(separator: " · ")
    }
}
