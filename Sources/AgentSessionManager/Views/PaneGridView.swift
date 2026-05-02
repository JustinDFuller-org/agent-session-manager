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
        GeometryReader { geo in
            let spacing = 4.0
            let padding = 4.0
            let rows = Double(layout.rows)
            let totalVertical = spacing * (rows - 1) + padding * 2
            let cellHeight = max(1, (geo.size.height - totalVertical) / rows)
            let cols = Array(repeating: GridItem(.flexible(), spacing: spacing), count: layout.columns)

            LazyVGrid(columns: cols, spacing: spacing) {
                ForEach(tab.panes) { pane in
                    PaneView(pane: pane, tab: tab)
                        .frame(height: cellHeight)
                        .id(pane.id)
                }
                ForEach(0..<layout.emptyCells, id: \.self) { _ in
                    Color.clear.frame(height: cellHeight)
                }
            }
            .padding(padding)
        }
    }

    private var tabEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("Press + to open a pane")
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .accessibilityIdentifier("tab-empty-state-\(tab.name)")
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
        .accessibilityIdentifier("add-pane-button")
    }
}
