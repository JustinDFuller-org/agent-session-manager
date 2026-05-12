import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    @State private var showingNewTab = false
    @State private var showCleanupAlert = false
    @State private var pendingCleanupPane: Pane?
    @State private var pendingCleanupTab: Tab?
    @State private var showPRMergedAlert = false
    @State private var pendingPRMergedPane: Pane?
    @State private var pendingPRMergedTab: Tab?
    @State private var showDebugLog = false
    @State private var debugLadybugRefreshTick = 0

    var body: some View {
        @Bindable var appState = appState
        let _ = debugLadybugRefreshTick
        let showDebugLadybug =
            appSettings.debugLoggingEnabled
            || !DebugLogger.shared.tracedPaneIDs.isEmpty
            || !DebugLogger.shared.tracedPaneTerminalCaptureIDs.isEmpty
        let hasNotifications = !appState.notifications.isEmpty
        VStack(spacing: 0) {
            TabBarView()
                .frame(height: 44)

            Divider()

            HStack(spacing: 0) {
                if appSettings.notificationSidebarSide == .left
                    && (hasNotifications
                        || appSettings.alwaysShowNotificationsSidebar)
                {
                    NotificationSidebarView()
                        .environment(appState)
                        .environment(appSettings)
                    Divider()
                }

                Group {
                    if appState.tabs.isEmpty {
                        EmptyStateView()
                    } else if let tab = appState.activeTab {
                        PaneGridView(tab: tab, onClosePane: handleClosePane)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appSettings.notificationSidebarSide == .right
                    && (hasNotifications
                        || appSettings.alwaysShowNotificationsSidebar)
                {
                    Divider()
                    NotificationSidebarView()
                        .environment(appState)
                        .environment(appSettings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .focusedSceneValue(\.hasActiveTab, !appState.tabs.isEmpty)
        .task {
            MacNotificationCoordinator.shared.bind(appState: appState, appSettings: appSettings)
            await MacNotificationCoordinator.shared.requestAuthorizationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.activePane?.terminalController?.focusTerminal()
            MacNotificationCoordinator.shared.removeAllDeliveredNotificationsIfStickyEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentSessionManagerDebugTracingChanged)) { _ in
            debugLadybugRefreshTick &+= 1
        }
        .overlay(alignment: .bottomTrailing) {
            if showDebugLadybug {
                Button {
                    showDebugLog = true
                } label: {
                    Image(systemName: "ladybug")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityIdentifier("debug-log-button")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in
            showingNewTab = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeTab)) { _ in
            closeActiveTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prMergedActionRequested)) { notif in
            guard
                let paneIDStr = notif.userInfo?["paneID"] as? String,
                let tabIDStr = notif.userInfo?["tabID"] as? String,
                let paneID = UUID(uuidString: paneIDStr),
                let tabID = UUID(uuidString: tabIDStr),
                let tab = appState.tabs.first(where: { $0.id == tabID }),
                let pane = tab.panes.first(where: { $0.id == paneID })
            else { return }
            pendingPRMergedPane = pane
            pendingPRMergedTab = tab
            showPRMergedAlert = true
        }
        .background(
            KeyboardShortcutView(
                appState: appState,
                onClosePane: closeActivePane,
                onCloseTab: closeActiveTab,
                onSwitchTab: switchTab
            )
        )
        .sheet(isPresented: $showingNewTab) {
            NewTabSheet()
        }
        .sheet(isPresented: $showDebugLog) {
            DebugLogView()
                .environment(appState)
                .environment(appSettings)
        }
        .alert("Close Worktree Pane", isPresented: $showCleanupAlert) {
            Button("Keep Worktree") {
                guard let pane = pendingCleanupPane, let tab = pendingCleanupTab else { return }
                pendingCleanupPane = nil
                pendingCleanupTab = nil
                tab.closePane(pane)
                SessionPersistence.save(appState: appState)
            }
            Button("Delete Worktree", role: .destructive) {
                guard let pane = pendingCleanupPane, let tab = pendingCleanupTab else { return }
                pendingCleanupPane = nil
                pendingCleanupTab = nil
                Task {
                    try? await tab.cleanupWorktree(for: pane)
                    await MainActor.run {
                        tab.closePane(pane)
                        SessionPersistence.save(appState: appState)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingCleanupPane = nil
                pendingCleanupTab = nil
            }
        } message: {
            if let pane = pendingCleanupPane {
                Text("The worktree \"\(pane.name)\" was created by Agent Session Manager. Would you like to delete it?")
            }
        }
        .alert("PR Merged", isPresented: $showPRMergedAlert) {
            Button("Close Pane") {
                guard let pane = pendingPRMergedPane, let tab = pendingPRMergedTab else { return }
                pendingPRMergedPane = nil
                pendingPRMergedTab = nil
                appState.clearNotification(paneID: pane.id)
                tab.closePane(pane)
                SessionPersistence.save(appState: appState)
            }
            Button("Close Pane and Clean Up Worktree", role: .destructive) {
                guard let pane = pendingPRMergedPane, let tab = pendingPRMergedTab else { return }
                pendingPRMergedPane = nil
                pendingPRMergedTab = nil
                appState.clearNotification(paneID: pane.id)
                Task {
                    try? await tab.cleanupWorktree(for: pane)
                    await MainActor.run {
                        tab.closePane(pane)
                        SessionPersistence.save(appState: appState)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                if let pane = pendingPRMergedPane, let tab = pendingPRMergedTab {
                    appState.focusPane(tabID: tab.id, paneID: pane.id)
                    appState.clearNotification(paneID: pane.id)
                }
                pendingPRMergedPane = nil
                pendingPRMergedTab = nil
            }
        } message: {
            if let pane = pendingPRMergedPane {
                let prInfo = pane.statusLineMonitor?.currentData?.pr
                if let pr = prInfo {
                    let msg =
                        "PR #\(pr.number) \"\(pr.title)\" for pane \"\(pane.name)\" has been merged. What would you like to do?"
                    Text(msg)
                } else {
                    Text("The PR for pane \"\(pane.name)\" has been merged. What would you like to do?")
                }
            }
        }
    }

    private func closeActivePane() {
        guard let tab = appState.activeTab else { return }
        let pane = appState.activePane ?? tab.panes.last
        guard let pane else { return }
        handleClosePane(pane)
    }

    private func handleClosePane(_ pane: Pane) {
        guard let tab = pane.tab else { return }
        switch appSettings.worktreeCleanupBehavior {
        case .ask where pane.worktreeIsManaged:
            pendingCleanupPane = pane
            pendingCleanupTab = tab
            showCleanupAlert = true
        case .delete where pane.worktreeIsManaged:
            Task {
                try? await tab.cleanupWorktree(for: pane)
                await MainActor.run {
                    tab.closePane(pane)
                    SessionPersistence.save(appState: appState)
                }
            }
        default:
            tab.closePane(pane)
            SessionPersistence.save(appState: appState)
        }
    }

    private func switchTab(index: Int) {
        guard index < appState.tabs.count else { return }
        appState.switchToTab(id: appState.tabs[index].id)
    }

    private func closeActiveTab() {
        guard let tab = appState.activeTab else { return }
        appState.closeTab(tab)
        SessionPersistence.save(appState: appState)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("Press ⌘T to create a tab")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("empty-state-hint")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HasActiveTabKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var hasActiveTab: Bool? {
        get { self[HasActiveTabKey.self] }
        set { self[HasActiveTabKey.self] = newValue }
    }
}

// Captures ⌘W / ⌘1-9 via local event monitor, and tracks active pane via mouse-down.
private struct KeyboardShortcutView: NSViewRepresentable {
    let appState: AppState
    let onClosePane: () -> Void
    let onCloseTab: () -> Void
    let onSwitchTab: (Int) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onClosePane = onClosePane
        coordinator.onCloseTab = onCloseTab
        coordinator.onSwitchTab = onSwitchTab
        coordinator.appState = appState
        guard coordinator.keyMonitor == nil else { return }

        coordinator.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Intercept Shift+Return so Claude CLI receives the Kitty keyboard protocol
            // Shift+Enter sequence (ESC [ 13 ; 2 u) instead of plain carriage return.
            // SwiftTerm's doCommand(by:) discards the shift modifier for insertNewline,
            // so we must send the correct sequence before the event reaches the terminal.
            let flags = event.modifierFlags.intersection([.shift, .command, .control, .option])
            if event.keyCode == 36 && flags == .shift,
                let termView = coordinator.appState?.activePane?.terminalController?.terminalView,
                !termView.terminal.keyboardEnhancementFlags.isEmpty
            {
                termView.send([0x1b, 0x5b, 0x31, 0x33, 0x3b, 0x32, 0x75])
                return nil
            }
            guard event.modifierFlags.contains(.command) else { return event }
            let closePaneKey = UserDefaults.standard.string(forKey: "keyBinding.closePaneKey") ?? "w"
            if let chars = event.characters, chars == closePaneKey {
                coordinator.onClosePane()
                return nil
            }
            let closeTabKey = UserDefaults.standard.string(forKey: "keyBinding.closeTabKey") ?? "k"
            if let chars = event.characters, chars == closeTabKey {
                coordinator.onCloseTab()
                return nil
            }
            if let chars = event.characters, let digit = Int(chars), (1...9).contains(digit) {
                coordinator.onSwitchTab(digit - 1)
                return nil
            }
            return event
        }

        coordinator.mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if let window = event.window {
                let loc = event.locationInWindow
                coordinator.updateActivePaneFromClick(at: loc, in: window)
            }
            return event
        }

        coordinator.scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            coordinator.handleScrollWheel(event: event)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        var onClosePane: () -> Void = {}
        var onCloseTab: () -> Void = {}
        var onSwitchTab: (Int) -> Void = { _ in }
        var appState: AppState?
        var keyMonitor: Any?
        var mouseMonitor: Any?
        var scrollWheelMonitor: Any?

        func updateActivePaneFromClick(at location: CGPoint, in window: NSWindow) {
            guard let appState, let tab = appState.activeTab else { return }
            for pane in tab.panes {
                guard let termView = pane.terminalController?.terminalView else { continue }
                let converted = termView.convert(location, from: nil)
                if termView.bounds.contains(converted) {
                    appState.setActivePane(id: pane.id)
                    return
                }
            }
        }

        func handleScrollWheel(event: NSEvent) -> NSEvent? {
            guard let window = event.window else { return event }
            guard abs(event.deltaY) >= 0.5 else { return event }
            let point = event.locationInWindow
            guard let hitView = window.contentView?.hitTest(point) else { return event }
            var view: NSView? = hitView
            while let current = view, !(current is BellCapturingTerminalView) {
                view = current.superview
            }
            guard let termView = view as? BellCapturingTerminalView else { return event }
            let terminal = termView.getTerminal()
            guard terminal.isCurrentBufferAlternate else { return event }
            guard termView.allowMouseReporting, terminal.mouseMode != .off else { return event }

            let localPoint = termView.convert(point, from: nil)
            let bw = termView.bounds.width
            let bh = termView.bounds.height
            guard bw > 0, bh > 0 else { return event }
            let cellX = max(0, min(terminal.cols - 1, Int(localPoint.x / bw * CGFloat(terminal.cols))))
            let terminalY = max(0, min(terminal.rows - 1, Int((1 - localPoint.y / bh) * CGFloat(terminal.rows))))
            let pixelX = Int(localPoint.x)
            let pixelY = Int(bh - localPoint.y)

            let button: Int = event.deltaY > 0 ? 4 : 5
            let flags = event.modifierFlags
            let pressFlags = terminal.encodeButton(
                button: button,
                release: false,
                shift: flags.contains(.shift),
                meta: flags.contains(.option),
                control: flags.contains(.control)
            )
            terminal.sendEvent(buttonFlags: pressFlags, x: cellX, y: terminalY, pixelX: pixelX, pixelY: pixelY)
            return nil
        }

        deinit {
            if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
            if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
            if let monitor = scrollWheelMonitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
