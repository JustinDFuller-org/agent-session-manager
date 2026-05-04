import SwiftUI

struct PaneView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    let pane: Pane
    let tab: Tab
    @State private var pulse = false

    private var isActive: Bool { appState.activePaneID == pane.id }

    var body: some View {
        VStack(spacing: 0) {
            paneHeader
            Divider()
            terminalBody
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
        .onTapGesture {
            appState.setActivePane(id: pane.id)
        }
    }

    private var paneHeader: some View {
        HStack(spacing: 6) {
            statusDot

            Text(pane.name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Button {
                tab.closePane(pane)
                SessionPersistence.save(appState: appState)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pane-close-\(pane.name)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pane-header-\(pane.name)")
    }

    @ViewBuilder
    private var statusDot: some View {
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

    @ViewBuilder
    private var statusLine: some View {
        if let monitor = pane.statusLineMonitor, monitor.currentData != nil {
            Divider()
            StatusLineView(monitor: monitor, config: appSettings.statusLineConfig)
        }
    }

    @ViewBuilder
    private var terminalBody: some View {
        if let controller = pane.terminalController {
            TerminalRepresentable(controller: controller, isActive: isActive)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color(nsColor: .textBackgroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
