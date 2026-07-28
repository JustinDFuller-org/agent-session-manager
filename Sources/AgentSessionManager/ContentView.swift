import AppKit
import SwiftUI

@main
struct AgentSessionManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var cleanupService: TraceCleanupService?

    var body: some Scene {
        // SwiftUI opens the first scene in this body automatically at launch, regardless of
        // whether AppDelegate already owns the visible main window (see #245, which removed
        // this scene on the premise that a Settings scene was the one opening a window).
        // `Window.defaultLaunchBehavior(.suppressed)` is the scene-level fix for this, but it
        // needs macOS 15 and the deployment floor is macOS 14 (project.yml, Package.swift), so
        // this Settings scene stays first as the non-launching placeholder. Keep it first —
        // moving a Window scene above it reopens the bug this PR fixes.
        Settings {
            EmptyView()
        }

        Window("Trace Dashboard", id: "trace-dashboard") {
            TraceDashboardView(
                tracesDirectory: appDelegate.appSettings.resolvedTracingDirectoryURL
            )
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
            .pinnedWindowChrome(Theme.dashboardWindowChrome)
        }
        .defaultSize(width: 900, height: 600)
        // The whole menu bar hangs off this modifier: SwiftUI ignores `.commands` on a
        // Settings scene, so AppCommands cannot move there even though this scene never
        // opens at launch.
        .commands { AppCommands(appState: appDelegate.appState) }

        Window("Invariant Dashboard", id: "invariant-dashboard") {
            InvariantDashboardView(
                directory: appDelegate.appSettings.resolvedInvariantDirectoryURL
            )
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
            .pinnedWindowChrome(Theme.dashboardWindowChrome)
        }
        .defaultSize(width: 900, height: 600)
    }
}

private struct AppCommands: Commands {
    let appState: AppState
    @AppStorage("keyBinding.newTabKey") var newTabKey = "t"
    @AppStorage("keyBinding.newPaneKey") var newPaneKey = "p"
    @AppStorage("keyBinding.closeTabKey") var closeTabKey = "k"
    @AppStorage("keyBinding.openShellHereKey") var openShellHereKey = "s"
    @AppStorage("keyBinding.viewPaneSettingsKey") var viewPaneSettingsKey = "i"
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings\u{2026}") {
                NotificationCenter.default.post(name: .toggleSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(after: .windowSize) {
            Button("Open Trace Dashboard") {
                openWindow(id: "trace-dashboard")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Open Invariant Dashboard") {
                openWindow(id: "invariant-dashboard")
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .newItem) {
            Button("New Tab") {
                NotificationCenter.default.post(name: .newTab, object: nil)
            }
            .keyboardShortcut(KeyEquivalent(Character(newTabKey)), modifiers: .command)

            Button("New Pane in Current Tab") {
                NotificationCenter.default.post(name: .newPane, object: nil)
            }
            .keyboardShortcut(KeyEquivalent(Character(newPaneKey)), modifiers: .command)
            .disabled(appState.tabs.isEmpty)

            Button("Open Shell Here") {
                NotificationCenter.default.post(name: .openShellHere, object: nil)
            }
            .keyboardShortcut(KeyEquivalent(Character(openShellHereKey)), modifiers: [.command, .shift])
            .disabled(appState.tabs.isEmpty)

            Button("View Pane Settings") {
                NotificationCenter.default.post(name: .viewPaneSettings, object: nil)
            }
            .keyboardShortcut(KeyEquivalent(Character(viewPaneSettingsKey)), modifiers: .command)
            .disabled(appState.activeTab?.panes.isEmpty ?? true)

            Divider()

            Button("Close Tab") {
                NotificationCenter.default.post(name: .closeTab, object: nil)
            }
            .keyboardShortcut(KeyEquivalent(Character(closeTabKey)), modifiers: .command)
            .disabled(appState.tabs.isEmpty)
        }
    }
}

extension Notification.Name {
    static let toggleSettings = Notification.Name("toggleSettings")
    static let newTab = Notification.Name("newTab")
    static let newPane = Notification.Name("newPane")
    static let closeTab = Notification.Name("closeTab")
    static let prResolutionActionRequested = Notification.Name("prResolutionActionRequested")
    static let openShellHere = Notification.Name("openShellHere")
    static let viewPaneSettings = Notification.Name("viewPaneSettings")
    static let agentSessionManagerPRTrackingSettingChanged = Notification.Name(
        "agentSessionManagerPRTrackingSettingChanged")
    static let agentSessionManagerCursorNotificationSettingChanged = Notification.Name(
        "agentSessionManagerCursorNotificationSettingChanged")
    static let showSettingsSection = Notification.Name("showSettingsSection")
}

extension AgentSessionManagerApp {
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }
}
