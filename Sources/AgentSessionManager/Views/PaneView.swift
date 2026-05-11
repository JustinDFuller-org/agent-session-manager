import AppKit
import SwiftUI

struct PaneView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    let pane: Pane
    let onClosePane: (Pane) -> Void
    @State private var pulse = false

    var body: some View {
        @Bindable var appState = appState
        let pendingNotification = appState.notifications.first { $0.paneID == pane.id }
        let isActive = appState.activePaneID == pane.id
        VStack(spacing: 0) {
            paneHeader(pendingNotification: pendingNotification)
            Divider()
            terminalBody(isActive: isActive)
            statusLine
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isActive ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.1),
                    lineWidth: isActive ? 1.5 : 1
                )
        )
        .contextMenu {
            Button("Close This Pane") {
                onClosePane(pane)
            }
            Button("Create Pane") {
                NotificationCenter.default.post(name: .newPane, object: nil)
            }
            if let pr = pane.statusLineMonitor?.currentData?.pr, let url = URL(string: pr.url) {
                Button("Go to Pull Request") {
                    NSWorkspace.shared.open(url)
                }
            }
            if appSettings.debugLoggingEnabled {
                Text(
                    "Global debug logging is on: every pane writes events to the trace file. Turn it off in Settings → General to limit tracing to selected panes."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Toggle(
                    "Trace this pane (events to trace file)",
                    isOn: Binding(
                        get: { DebugLogger.shared.tracedPaneIDs.contains(pane.id) },
                        set: { DebugLogger.shared.setPaneTraceEnabled(pane.id, $0) }
                    ))
            }

            if appSettings.debugLoggingEnabled && appSettings.debugLogIncludeTerminalContents {
                Text(
                    "Global “include terminal snapshots” is on: Capture Terminal from the debug sheet includes every pane."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Toggle(
                    "Include this pane’s terminal in trace captures",
                    isOn: Binding(
                        get: { DebugLogger.shared.tracedPaneTerminalCaptureIDs.contains(pane.id) },
                        set: { DebugLogger.shared.setPaneTerminalCaptureEnabled(pane.id, $0) }
                    )
                )
                .disabled(appSettings.debugLoggingEnabled && appSettings.debugLogIncludeTerminalContents)
            }

            if appSettings.debugLoggingEnabled
                || !DebugLogger.shared.tracedPaneIDs.isEmpty
                || !DebugLogger.shared.tracedPaneTerminalCaptureIDs.isEmpty
            {
                Button("Report a Bug…") {
                    DebugLogger.openBugReport(traceFilePath: appSettings.resolvedDebugLogFileURL.path)
                }
            }
        }
        .onTapGesture {
            appState.setActivePane(id: pane.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentSessionManagerClaudeHookAttentionSettingChanged)) {
            _ in
            pane.statusLineMonitor?.refreshClaudeIntegrationFromSettings()
        }
        .accessibilityElement(children: .contain)
    }

    private func paneHeader(pendingNotification: PaneNotification?) -> some View {
        HStack(spacing: 6) {
            statusDot(pendingNotification: pendingNotification)

            if let notification = pendingNotification, notification.kind == .terminalBell {
                Circle()
                    .fill(notification.isPriority ? Color.orange : Color.accentColor)
                    .frame(width: 7, height: 7)
                    .accessibilityIdentifier("pane-notification-dot-\(pane.name)")
            }

            Text(pane.name)
                .accessibilityIdentifier("pane-name-\(pane.name)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Button {
                appState.clearNotification(paneID: pane.id)
                onClosePane(pane)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pane-close-\(pane.name)")
            .accessibilityLabel("close-\(pane.name)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("pane-header-\(pane.name)")
        .onHover { isHovering in
            if isHovering { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
        .draggable(pane.id.uuidString) {
            Text(pane.name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private func statusDot(pendingNotification: PaneNotification?) -> some View {
        if pane.isMerged {
            Circle()
                .fill(Color.purple)
                .frame(width: 7, height: 7)
                .accessibilityIdentifier("pane-status-dot-merged-\(pane.name)")
        } else {
            switch pane.terminalController?.processState {
            case .running:
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                    .opacity(pulse ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            case .exited:
                Circle().fill(Color.gray.opacity(0.4)).frame(width: 7, height: 7)
            default:
                Circle().fill(Color.gray).frame(width: 7, height: 7)
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let monitor = pane.statusLineMonitor, monitor.currentData != nil {
            Divider()
            StatusLineView(monitor: monitor, config: appSettings.statusLineConfig)
        }
    }

    @ViewBuilder
    private func terminalBody(isActive: Bool) -> some View {
        if let controller = pane.terminalController {
            TerminalRepresentable(controller: controller, isActive: isActive)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        } else {
            Color(nsColor: .textBackgroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
    }
}
