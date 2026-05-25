import SwiftUI

struct PaneGridView: View {
    @Environment(AppState.self) private var appState
    @State private var showingNewPane = false
    @State private var dragTargetPaneID: UUID?
    let tab: Tab
    let onClosePane: (Pane) -> Void
    let onRefreshPane: (Pane) -> Void

    private var layout: GridLayout {
        GridLayout.layout(for: tab.panes.count)
    }

    var body: some View {
        Group {
            if tab.panes.isEmpty {
                tabEmptyState
            } else {
                panesGrid
            }
        }
        .sheet(
            isPresented: $showingNewPane,
            onDismiss: {
                appState.activePane?.terminalController?.focusTerminal()
            },
            content: {
                NewPaneSheet(tab: tab)
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .newPane)) { _ in
            showingNewPane = true
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
                    PaneView(pane: pane, onClosePane: onClosePane, onRefreshPane: onRefreshPane)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("pane-\(pane.name)")
                        .frame(height: cellHeight)
                        .id(pane.id)
                        .overlay(
                            dragTargetPaneID == pane.id
                                ? RoundedRectangle(cornerRadius: 8).strokeBorder(
                                    Color.accentColor.opacity(0.6), lineWidth: 2)
                                : nil
                        )
                        .dropDestination(for: String.self) { items, _ in
                            guard
                                let droppedID = items.first,
                                let droppedUUID = UUID(uuidString: droppedID),
                                let from = tab.panes.firstIndex(where: { $0.id == droppedUUID }),
                                let to = tab.panes.firstIndex(where: { $0.id == pane.id }),
                                from != to
                            else { return false }
                            tab.movePane(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
                            SessionPersistence.save(appState: appState)
                            return true
                        } isTargeted: { isTargeted in
                            dragTargetPaneID = isTargeted ? pane.id : nil
                        }
                }
                ForEach(0..<layout.emptyCells, id: \.self) { _ in
                    Color.clear.frame(height: cellHeight)
                }
            }
            .padding(padding)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Create Pane") {
                showingNewPane = true
            }
        }
    }

    private var tabEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("Press ⌘P to open a pane")
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .accessibilityIdentifier("tab-empty-state-\(tab.name)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Create Pane") {
                showingNewPane = true
            }
        }
    }
}
