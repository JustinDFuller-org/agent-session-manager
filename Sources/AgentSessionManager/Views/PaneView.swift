import AppKit
import SwiftUI

struct PaneView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    let pane: Pane
    let onClosePane: (Pane) -> Void
    let onRefreshPane: (Pane) -> Void
    @State private var pulse = false

    var body: some View {
        @Bindable var appState = appState
        let pendingNotification = appState.notifications.first { $0.paneID == pane.id }
        let isActive = appState.activePaneID == pane.id
        ZStack {
            VStack(spacing: 0) {
                paneHeader(pendingNotification: pendingNotification)
                Divider()
                terminalBody(isActive: isActive)
                statusLine
            }

            if case .exited(let code) = pane.terminalController?.processState,
                appSettings.exitBehavior == .prompt
            {
                exitPromptView(exitCode: code)
            }
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
        .onChange(of: pane.terminalController?.processState) { _, newState in
            guard case .exited = newState else { return }
            switch appSettings.exitBehavior {
            case .prompt:
                break
            case .autoShell:
                pane.tab?.openShellInPane(pane)
            case .close:
                onClosePane(pane)
            }
        }
        .contextMenu {
            Button("Close This Pane") {
                onClosePane(pane)
            }
            if pane.cliType != .shell {
                Button("Refresh Pane\u{2026}") {
                    onRefreshPane(pane)
                }
            }
            Button("Create Pane") {
                NotificationCenter.default.post(name: .newPane, object: nil)
            }
            Button("Open Shell Here") {
                pane.tab?.openShellPane(activePane: pane)
            }
            if let pr = pane.statusLineMonitor?.currentData?.pr, let url = URL(string: pr.url) {
                Button("Go to Pull Request") {
                    NSWorkspace.shared.open(url)
                }
            }
            if appSettings.isPriorityNotificationsEnabled {
                Toggle(
                    "Priority Pane",
                    isOn: Binding(
                        get: { pane.isPriority },
                        set: { newValue in
                            pane.isPriority = newValue
                            SessionPersistence.save(appState: appState)
                        }
                    )
                )
            }
        }
        .onTapGesture {
            appState.setActivePane(id: pane.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentSessionManagerClaudeHookAttentionSettingChanged)) {
            _ in
            pane.statusLineMonitor?.refreshClaudeIntegrationFromSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentSessionManagerPRTrackingSettingChanged)) { _ in
            pane.statusLineMonitor?.refreshClaudeIntegrationFromSettings()
        }
        .accessibilityElement(children: .contain)
    }

    private func paneHeader(pendingNotification: PaneNotification?) -> some View {
        HStack(spacing: 6) {
            statusDot()

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
        .accessibilityElement(children: .contain)
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
    private func statusDot() -> some View {
        let pr = pane.statusLineMonitor?.currentData?.pr
        let sessionState = pane.statusLineMonitor?.currentData?.sessionStatus?.state
        let shouldPulse = sessionState == "busy" || sessionState == "retry"
        let dotColor = paneStatusDotColor(
            pr: pr,
            isMerged: pane.isMerged,
            processState: pane.terminalController?.processState
        )
        let isMergedCondition = pane.isMerged || pr?.state.lowercased() == "merged"
        let dotAccessibilityID =
            isMergedCondition
            ? "pane-status-dot-merged-\(pane.name)"
            : "pane-status-dot-\(pane.name)"

        Circle()
            .fill(dotColor)
            .frame(width: 7, height: 7)
            .opacity(pulse ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = shouldPulse }
            .onChange(of: shouldPulse) { _, newValue in
                if newValue {
                    pulse = true
                } else {
                    withAnimation(.linear(duration: 0)) { pulse = false }
                }
            }
            .accessibilityIdentifier(dotAccessibilityID)
            .accessibilityLabel(isMergedCondition ? "merged pane status" : "pane status")
    }

    @ViewBuilder
    private var statusLine: some View {
        if let monitor = pane.statusLineMonitor, monitor.currentData != nil {
            Divider()
            let config = resolvedStatusLineConfig
            StatusLineView(monitor: monitor, config: config, profileName: resolvedProfileName)
        }
    }

    private var resolvedStatusLineConfig: StatusLineConfig {
        if let profileID = pane.profileID,
            let profile = appSettings.profiles.first(where: { $0.id == profileID }),
            let override = profile.statusLineConfig
        {
            return override
        }
        return appSettings.statusLineConfig
    }

    private var resolvedProfileName: String? {
        guard let profileID = pane.profileID else { return nil }
        return appSettings.profiles.first { $0.id == profileID }?.name
    }

    @ViewBuilder
    private func terminalBody(isActive: Bool) -> some View {
        if let controller = pane.terminalController {
            TerminalRepresentable(
                controller: controller,
                isActive: isActive,
                scrollbackLines: appSettings.scrollbackLines
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .id(pane.restartToken)
        } else if case .failed(let error) = pane.setupState {
            paneSetupErrorView(error: error)
        } else if case .loading = pane.setupState {
            paneLoadingView
        } else {
            Color(nsColor: .textBackgroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
    }

    @ViewBuilder
    private var paneLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Setting up workspace\u{2026}")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("pane-loading-overlay-\(pane.name)")
    }

    @ViewBuilder
    private func paneSetupErrorView(error: String) -> some View {
        VStack(spacing: 12) {
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Button("Remove Pane") { onClosePane(pane) }
                .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("pane-error-overlay-\(pane.name)")
    }

    @ViewBuilder
    private func exitPromptView(exitCode: Int32?) -> some View {
        VStack(spacing: 12) {
            Text("Process exited\(exitCode.map { " (code \($0))" } ?? "")")
                .font(.subheadline)
                .foregroundStyle(.primary)
            HStack(spacing: 8) {
                Button("Restart") { pane.tab?.restartPane(pane) }
                Button("Open Shell") { pane.tab?.openShellInPane(pane) }
                Button("Close") { onClosePane(pane) }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
        .accessibilityIdentifier("pane-exit-prompt-\(pane.name)")
    }
}
