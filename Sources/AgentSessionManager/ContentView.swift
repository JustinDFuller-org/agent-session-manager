import SwiftUI
import AppKit

@main
struct AgentSessionManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup("Agent Session Manager") {
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
                        SettingsPersistence.restoreActiveTools(into: appSettings)
                        SettingsPersistence.restoreDefaultBranch(into: appSettings)
                        SettingsPersistence.restoreNotificationSettings(into: appSettings)
                        SettingsPersistence.restoreRestartSettings(into: appSettings)
                        SettingsPersistence.restoreWorktreeCleanup(into: appSettings)
                        SessionPersistence.restore(into: appState, appSettings: appSettings)
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
    }
}

private struct AppCommands: Commands {
    @AppStorage("keyBinding.newTabKey") var newTabKey = "t"
    @AppStorage("keyBinding.newPaneKey") var newPaneKey = "p"
    @AppStorage("keyBinding.closeTabKey") var closeTabKey = "k"
    @FocusedValue(\.hasActiveTab) var hasActiveTab

    var body: some Commands {
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
}

extension AgentSessionManagerApp {
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }
}
