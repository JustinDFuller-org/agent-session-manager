import AppKit
import SwiftUI

@main
struct AgentSessionManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var cleanupService: TraceCleanupService?

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.appSettings)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .windowResizability(.contentSize)
        .commands { AppCommands(appState: appDelegate.appState) }

        Window("Trace Dashboard", id: "trace-dashboard") {
            TraceDashboardView(
                tracesDirectory: appDelegate.appSettings.resolvedTracingDirectoryURL
            )
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
        .defaultSize(width: 900, height: 600)

        Window("Invariant Dashboard", id: "invariant-dashboard") {
            InvariantDashboardView(
                directory: appDelegate.appSettings.resolvedInvariantDirectoryURL
            )
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
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
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
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
    static let newTab = Notification.Name("newTab")
    static let newPane = Notification.Name("newPane")
    static let closeTab = Notification.Name("closeTab")
    static let prMergedActionRequested = Notification.Name("prMergedActionRequested")
    static let openShellHere = Notification.Name("openShellHere")
    static let agentSessionManagerPRTrackingSettingChanged = Notification.Name(
        "agentSessionManagerPRTrackingSettingChanged")
}

extension AgentSessionManagerApp {
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }
}
