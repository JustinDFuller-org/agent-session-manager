import AppKit
import Darwin
import SwiftUI

@main
struct AgentSessionManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var cleanupService: TraceCleanupService?

    init() {
        // Every subprocess pipe (git diff, gh api, custom status-line commands, the PTY
        // master fd) can outlive its reader. Without this, a write to any of them after the
        // other end closes delivers SIGPIPE with no handler installed, which terminates the
        // whole process instantly and leaves no crash report, no termination span, and no
        // marker update — see the 2026-08-12 13:56:04 unattended exit this call prevents.
        signal(SIGPIPE, SIG_IGN)
    }

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

        Window(AuxiliaryWindow.traceDashboard.title, id: AuxiliaryWindow.traceDashboard.rawValue) {
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

        Window(AuxiliaryWindow.invariantDashboard.title, id: AuxiliaryWindow.invariantDashboard.rawValue) {
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
                AuxiliaryWindowRegistry.open(.traceDashboard, using: openWindow)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Open Invariant Dashboard") {
                AuxiliaryWindowRegistry.open(.invariantDashboard, using: openWindow)
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
