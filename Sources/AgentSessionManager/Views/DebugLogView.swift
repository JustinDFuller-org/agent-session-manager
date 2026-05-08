import SwiftUI
import AppKit

struct DebugLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var debug = DebugLogger.shared
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Debug Log")
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Button("Capture Terminal") {
                        for tab in appState.tabs {
                            for pane in tab.panes {
                                guard let content = pane.terminalController?.terminalContent,
                                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                else { continue }
                                DebugLogger.shared.logTerminalContent(paneName: pane.name, content: content)
                            }
                        }
                    }
                    .disabled(debug.isEnabled == false || appState.tabs.isEmpty)
                    .accessibilityIdentifier("debug-log-capture-button")

                    Button("Copy") {
                        let text = debug.entries.map { entry in
                            let df = DateFormatter()
                            df.dateFormat = "HH:mm:ss.SSS"
                            return "[\(df.string(from: entry.timestamp))] \(entry.message)"
                        }.joined(separator: "\n\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .disabled(debug.entries.isEmpty)
                    .accessibilityIdentifier("debug-log-copy-button")

                    Button("Clear") {
                        debug.clear()
                    }
                    .disabled(debug.entries.isEmpty)
                    .accessibilityIdentifier("debug-log-clear-button")

                    Button("Report Bug") {
                        DebugLogger.openBugReport()
                    }
                    .disabled(debug.entries.isEmpty)
                    .accessibilityIdentifier("debug-log-report-button")
                }
            }

            if debug.entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("No log entries yet.\nPerform actions in the app with debug logging enabled to see details here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("debug-log-empty-state")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(debug.entries) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formattedTimestamp(entry.timestamp))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                    Text(entry.message)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 4)
                        .id("bottom")
                    }
                    .onChange(of: debug.entries.count) {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(
                "Telemetry buffer: \(debug.entries.count) / \(DebugLogger.telemetryEntryCap) entries — total dropped (cap): \(debug.totalEntriesDropped)"
            )
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
        .frame(minWidth: 600, idealWidth: 700, minHeight: 400, idealHeight: 500)
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df.string(from: date)
    }
}
