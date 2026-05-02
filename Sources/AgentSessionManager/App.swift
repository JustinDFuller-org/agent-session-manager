import SwiftUI

@main
struct AgentSessionManagerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("Agent Session Manager") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .task { if !CommandLine.arguments.contains("--uitesting-skip-restore") { SessionPersistence.restore(into: appState) } }
                .onChange(of: appState.tabs.count) { SessionPersistence.save(appState: appState) }
                .onChange(of: appState.activeTabID) { SessionPersistence.save(appState: appState) }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let newTab = Notification.Name("newTab")
}

extension AgentSessionManagerApp {
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }
}
