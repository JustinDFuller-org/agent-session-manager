import SwiftUI

struct PaneGridView: View {
    @Environment(AppState.self) private var appState
    @State private var showingNewPane = false
    let tab: Tab

    private var layout: GridLayout {
        GridLayout.layout(for: tab.panes.count)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if tab.panes.isEmpty {
                tabEmptyState
            } else {
                panesGrid
            }

            addPaneButton
        }
        .sheet(isPresented: $showingNewPane) {
            NewPaneSheet(tab: tab)
        }
    }

    private var panesGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: layout.columns)
        return LazyVGrid(columns: cols, spacing: 4) {
            ForEach(tab.panes) { pane in
                PaneView(pane: pane, tab: tab)
                    .id(pane.id)
            }
            ForEach(0..<layout.emptyCells, id: \.self) { _ in
                Color.clear
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tabEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("Press + to open a pane")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addPaneButton: some View {
        Button {
            showingNewPane = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.accentColor))
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .padding(16)
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
}
