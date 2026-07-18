import SwiftUI

struct TabBarView: View {
    @Environment(AppState.self) private var appState
    @State private var updateCheckCoordinator = UpdateCheckCoordinator.shared

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(appState.tabs) { tab in
                        TabButtonView(tab: tab)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .contextMenu {
                Button("Create Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
            }

            if updateCheckCoordinator.updateAvailable {
                UpdatePillView()
                    .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBackground)
    }
}

private struct UpdatePillView: View {
    @State private var coordinator = UpdateCheckCoordinator.shared

    var body: some View {
        Button {
            if coordinator.channel == .dmg {
                coordinator.performUpdate()
            } else {
                NotificationCenter.default.post(name: .toggleSettings, object: nil)
                NotificationCenter.default.post(
                    name: .showSettingsSection, object: nil,
                    userInfo: ["section": SettingsSection.about.rawValue])
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle")
                Text("Update available")
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.accent))
            .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("update-available-pill")
    }
}
