import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showingNewTab = false

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(showingNewTab: $showingNewTab)
                .frame(height: 44)

            Divider()

            if appState.tabs.isEmpty {
                EmptyStateView()
            } else if let tab = appState.activeTab {
                PaneGridView(tab: tab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in
            showingNewTab = true
        }
        .background(KeyboardShortcutView(
            appState: appState,
            onClosePane: closeActivePane,
            onSwitchTab: switchTab
        ))
        .sheet(isPresented: $showingNewTab) {
            NewTabSheet()
        }
    }

    private func closeActivePane() {
        guard let tab = appState.activeTab else { return }
        let pane = appState.activePane ?? tab.panes.last
        guard let pane else { return }
        tab.closePane(pane)
        SessionPersistence.save(appState: appState)
    }

    private func switchTab(index: Int) {
        guard index < appState.tabs.count else { return }
        appState.activeTabID = appState.tabs[index].id
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Press ⌘T to create a tab")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Captures ⌘W / ⌘1-9 via local event monitor, and tracks active pane via mouse-down.
private struct KeyboardShortcutView: NSViewRepresentable {
    let appState: AppState
    let onClosePane: () -> Void
    let onSwitchTab: (Int) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let c = context.coordinator
        c.onClosePane = onClosePane
        c.onSwitchTab = onSwitchTab
        c.appState = appState
        guard c.keyMonitor == nil else { return }

        c.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }
            if event.keyCode == 13 { // w
                c.onClosePane()
                return nil
            }
            if let chars = event.characters, let digit = Int(chars), (1...9).contains(digit) {
                c.onSwitchTab(digit - 1)
                return nil
            }
            return event
        }

        c.mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if let window = event.window {
                let loc = event.locationInWindow
                c.updateActivePaneFromClick(at: loc, in: window)
            }
            return event
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        var onClosePane: () -> Void = {}
        var onSwitchTab: (Int) -> Void = { _ in }
        var appState: AppState?
        var keyMonitor: Any?
        var mouseMonitor: Any?

        func updateActivePaneFromClick(at location: CGPoint, in window: NSWindow) {
            guard let appState, let tab = appState.activeTab else { return }
            for pane in tab.panes {
                guard let termView = pane.terminalController?.terminalView else { continue }
                let converted = termView.convert(location, from: nil)
                if termView.bounds.contains(converted) {
                    appState.activePaneID = pane.id
                    return
                }
            }
        }

        deinit {
            if let m = keyMonitor { NSEvent.removeMonitor(m) }
            if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        }
    }
}
