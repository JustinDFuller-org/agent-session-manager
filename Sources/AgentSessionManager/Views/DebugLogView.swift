import SwiftUI
import AppKit

struct DebugLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
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
                    .disabled(DebugLogger.shared.isEnabled == false || appState.tabs.isEmpty)
                    .accessibilityIdentifier("debug-log-capture-button")

                    Button("Copy") {
                        let text = DebugLogger.shared.entries.map { entry in
                            let df = DateFormatter()
                            df.dateFormat = "HH:mm:ss.SSS"
                            return "[\(df.string(from: entry.timestamp))] \(entry.message)"
                        }.joined(separator: "\n\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .disabled(DebugLogger.shared.entries.isEmpty)
                    .accessibilityIdentifier("debug-log-copy-button")

                    Button("Clear") {
                        DebugLogger.shared.clear()
                    }
                    .disabled(DebugLogger.shared.entries.isEmpty)
                    .accessibilityIdentifier("debug-log-clear-button")

                    Button("Report Bug") {
                        reportBug()
                    }
                    .disabled(DebugLogger.shared.entries.isEmpty)
                    .accessibilityIdentifier("debug-log-report-button")
                }
            }

            if DebugLogger.shared.entries.isEmpty {
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
                            ForEach(DebugLogger.shared.entries) { entry in
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
                    .onChange(of: DebugLogger.shared.entries.count) {
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

    private func reportBug() {
        let body = DebugLogger.shared.buildReportText()
        let title = "[Bug] "
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return }
        let urlString = "https://github.com/JustinDFuller/agent-session-manager/issues/new?title=\(encodedTitle)&body=\(encodedBody)"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
