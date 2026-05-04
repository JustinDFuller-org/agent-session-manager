import SwiftUI

struct TabButtonView: View {
    @Environment(AppState.self) private var appState
    let tab: Tab

    private var isActive: Bool {
        appState.activeTabID == tab.id
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tab.name)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        .lineLimit(1)
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
            .highPriorityGesture(TapGesture().onEnded {
                appState.switchToTab(id: tab.id)
            })
            .accessibilityIdentifier("tab-button-\(tab.name)")
            .accessibilityValue(isActive ? "active" : "inactive")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) {
                appState.switchToTab(id: tab.id)
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
                .strokeBorder(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}
