import SwiftUI

struct TabBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(appState.tabs) { tab in
                    TabButtonView(tab: tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.opacity(0.95))
        .contextMenu {
            Button("Create Tab") {
                NotificationCenter.default.post(name: .newTab, object: nil)
            }
        }
    }
}
