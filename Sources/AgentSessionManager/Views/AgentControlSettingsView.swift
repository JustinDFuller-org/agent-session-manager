import SwiftUI

struct AgentControlSettingsSection: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings

        Section("Agent Control") {
            SettingRow(
                title: "Injection Policy",
                description: appSettings.agentControlInjectionPolicy.description,
                defaultValue: "Ask (on by default)"
            ) {
                Picker("Injection Policy", selection: $appSettings.agentControlInjectionPolicy) {
                    ForEach(AgentControlInjectionPolicy.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
                .accessibilityIdentifier("settings-agent-control-injection-policy-picker")
                .onChange(of: appSettings.agentControlInjectionPolicy) {
                    SettingsPersistence.saveAgentControlSettings(appSettings: appSettings)
                }
            }
            SettingRow(
                title: "Scope",
                description: appSettings.agentControlScope.description,
                defaultValue: "Pane"
            ) {
                Picker("Scope", selection: $appSettings.agentControlScope) {
                    ForEach(AgentControlScope.allCases, id: \.self) { scope in
                        Text(scope.displayName)
                            .tag(scope)
                            .accessibilityIdentifier("settings-agent-control-scope-option-\(scope.rawValue)")
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("settings-agent-control-scope-picker")
                .onChange(of: appSettings.agentControlScope) {
                    SettingsPersistence.saveAgentControlSettings(appSettings: appSettings)
                }
            }
        }
    }
}
