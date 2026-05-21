import AppKit
import SwiftUI

@main
struct AgentSessionManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var appSettings = AppSettings()

    var body: some Scene {
        Window(appWindowTitle, id: "main") {
            ContentView()
                .environment(appState)
                .environment(appSettings)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    if !CommandLine.arguments.contains("--uitesting-skip-restore") {
                        SettingsPersistence.restore(into: appSettings)
                        SettingsPersistence.restoreStatusLine(into: appSettings)
                        SettingsPersistence.restoreCodexOptions(into: appSettings)
                        SettingsPersistence.restoreCursorOptions(into: appSettings)
                        SettingsPersistence.restoreOpenCodeOptions(into: appSettings)
                        SettingsPersistence.restoreActiveTools(into: appSettings)
                        SettingsPersistence.restoreDefaultBranch(into: appSettings)
                        SettingsPersistence.restoreNotificationSettings(into: appSettings)
                        SettingsPersistence.restoreRestartSettings(into: appSettings)
                        SettingsPersistence.restoreWorktreeCleanup(into: appSettings)
                        SettingsPersistence.restoreExistingWorktreeManagement(into: appSettings)
                        SettingsPersistence.restoreWorktreeBaseRef(into: appSettings)
                        SettingsPersistence.restorePRTracking(into: appSettings)
                        SettingsPersistence.restorePRPollingSettings(into: appSettings)
                        SettingsPersistence.restoreTerminalSettings(into: appSettings)
                        SettingsPersistence.restoreExitBehavior(into: appSettings)
                        SettingsPersistence.restoreEnvVarOptions(into: appSettings)
                        SettingsPersistence.restoreProfiles(into: appSettings)
                        SettingsPersistence.restoreSessionNameSettings(into: appSettings)
                        SettingsPersistence.restoreTracingSettings(into: appSettings)
                        TracingService.shared.configure(from: appSettings)
                        SessionPersistence.restore(into: appState, appSettings: appSettings)
                        await SessionPersistence.checkForMergedPRsAfterRestore(appState: appState)
                    }
                }
                .onChange(of: appState.tabs.count) { SessionPersistence.save(appState: appState) }
                .onChange(of: appState.activeTabID) { SessionPersistence.save(appState: appState) }
        }
        .commands { AppCommands() }

        Settings {
            SettingsView()
                .environment(appSettings)
        }

        Window("Trace Dashboard", id: "trace-dashboard") {
            TraceDashboardView()
                .environment(TraceStore.shared)
        }
    }
}

private struct AppCommands: Commands {
    @AppStorage("keyBinding.newTabKey") var newTabKey = "t"
    @AppStorage("keyBinding.newPaneKey") var newPaneKey = "p"
    @AppStorage("keyBinding.closeTabKey") var closeTabKey = "k"
    @AppStorage("keyBinding.openShellHereKey") var openShellHereKey = "s"
    @FocusedValue(\.hasActiveTab) var hasActiveTab
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
        CommandGroup(after: .windowSize) {
            Button("Open Trace Dashboard") {
                openWindow(id: "trace-dashboard")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
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
            .disabled(!(hasActiveTab ?? false))

            Button("Open Shell Here") {
                NotificationCenter.default.post(name: .openShellHere, object: nil)
            }
            .keyboardShortcut(KeyEquivalent(Character(openShellHereKey)), modifiers: [.command, .shift])
            .disabled(!(hasActiveTab ?? false))

            Divider()

            Button("Close Tab") {
                NotificationCenter.default.post(name: .closeTab, object: nil)
            }
            .keyboardShortcut(KeyEquivalent(Character(closeTabKey)), modifiers: .command)
            .disabled(!(hasActiveTab ?? false))
        }
    }
}

extension Notification.Name {
    static let newTab = Notification.Name("newTab")
    static let newPane = Notification.Name("newPane")
    static let closeTab = Notification.Name("closeTab")
    static let prMergedActionRequested = Notification.Name("prMergedActionRequested")
    static let openShellHere = Notification.Name("openShellHere")
    static let agentSessionManagerClaudeHookAttentionSettingChanged = Notification.Name(
        "agentSessionManagerClaudeHookAttentionSettingChanged")
    static let agentSessionManagerPRTrackingSettingChanged = Notification.Name(
        "agentSessionManagerPRTrackingSettingChanged")
}

extension AgentSessionManagerApp {
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    static var shouldSimulateBannerClick: Bool {
        CommandLine.arguments.contains("--uitesting-simulate-banner-click")
    }

    private var appWindowTitle: String {
        #if DEV_BUILD
        "Agent Session Manager (Dev)"
        #else
        "Agent Session Manager"
        #endif
    }
}
