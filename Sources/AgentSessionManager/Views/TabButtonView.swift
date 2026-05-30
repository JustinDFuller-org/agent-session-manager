import SwiftUI

struct TabButtonView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    let tab: Tab
    @State private var isDragTarget = false

    private var isActive: Bool {
        appState.activeTabID == tab.id
    }

    var body: some View {
        @Bindable var appState = appState
        let tabPaneIDs = Set(tab.panes.map(\.id))
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        let tabActivityStateValue = tabActivityState(
                            tab.panes.map { pane in
                                paneActivityState(
                                    processState: pane.terminalController?.processState,
                                    isProducingOutput: pane.terminalController?.isProducingOutput ?? false,
                                    sessionState: pane.statusLineMonitor?.currentData?.sessionStatus?.state,
                                    hasNotification: tabPaneIDs.contains(pane.id)
                                        && appState.notifications.contains { $0.paneID == pane.id }
                                )
                            })
                        ActivityIndicatorView(
                            state: tabActivityStateValue,
                            enabled: appSettings.paneActivityIndicatorsEnabled,
                            prefix: "tab",
                            name: tab.name
                        )
                        Text(tab.name)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    Text(tab.directoryDisplayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, 10)
            .padding(.trailing, 4)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    appState.switchToTab(id: tab.id)
                }
            )
            .accessibilityIdentifier("tab-button-\(tab.name)")
            .accessibilityValue(isActive ? "active" : "inactive")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) {
                appState.switchToTab(id: tab.id)
            }
            .onHover { isHovering in
                if isHovering { NSCursor.openHand.push() } else { NSCursor.pop() }
            }

            Button {
                appState.closeTab(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
            .accessibilityIdentifier("tab-close-\(tab.name)")
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isDragTarget
                        ? Color.accentColor.opacity(0.6) : (isActive ? Color.accentColor.opacity(0.4) : Color.clear),
                    lineWidth: isDragTarget ? 2 : 1
                )
        )
        .draggable(tab.id.uuidString) {
            Text(tab.name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .dropDestination(for: String.self) { items, _ in
            guard
                let droppedID = items.first,
                let droppedUUID = UUID(uuidString: droppedID),
                let from = appState.tabs.firstIndex(where: { $0.id == droppedUUID }),
                let to = appState.tabs.firstIndex(where: { $0.id == tab.id }),
                from != to
            else { return false }
            appState.moveTab(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
            return true
        } isTargeted: { isTargeted in
            isDragTarget = isTargeted
        }
        .contextMenu {
            Button("Create Tab") {
                NotificationCenter.default.post(name: .newTab, object: nil)
            }
            Button("Delete This Tab") {
                appState.closeTab(tab)
            }
            Button("Create Pane") {
                appState.switchToTab(id: tab.id)
                NotificationCenter.default.post(name: .newPane, object: nil)
            }
        }
    }
}
