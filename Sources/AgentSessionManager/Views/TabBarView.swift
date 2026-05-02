import SwiftUI

struct TabBarView: View {
    @Environment(AppState.self) private var appState
    @Binding var showingNewTab: Bool

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

            Divider()
                .frame(height: 20)

            Button {
                showingNewTab = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .accessibilityIdentifier("new-tab-button")
        }
        .background(.background.opacity(0.95))
    }
}
