import Testing

@testable import AgentSessionManager

@MainActor
@Suite("NewPaneOptionVisibility")
struct NewPaneOptionVisibilityTests {
    @Test("CLI visibility includes enabled and show-on-pane-create profile options")
    func cliVisibilityIncludesEnabledAndShownOptions() {
        let catalog = [
            CLIOptionConfig(
                id: "--verbose", label: "Verbose", description: "Verbose logging",
                isAvailable: true, isDefaultEnabled: false
            ),
            CLIOptionConfig(
                id: "--model", label: "Model", description: "Model",
                isAvailable: false, isDefaultEnabled: false
            ),
            CLIOptionConfig(
                id: "--continue", label: "Continue", description: "Continue",
                isAvailable: true, isDefaultEnabled: false
            ),
            CLIOptionConfig(
                id: "--resume", label: "Resume", description: "Resume",
                isAvailable: true, isDefaultEnabled: false
            ),
        ]
        let profile = Profile(
            name: "Visibility",
            harness: .claude,
            cliOptions: [
                ProfileCLIOption(id: "--model", isEnabled: true, value: "claude-sonnet"),
                ProfileCLIOption(id: "--continue", isEnabled: false, showOnPaneCreate: true),
                ProfileCLIOption(id: "--verbose", isEnabled: false),
                ProfileCLIOption(id: "--resume", isEnabled: true, showOnPaneCreate: true),
            ]
        )

        let visible = NewPaneSheet.defaultVisibleCLIOptions(catalog: catalog, profile: profile)

        #expect(visible.map(\.id) == ["--model", "--continue", "--resume"])
    }

    @Test("CLI custom pane keeps available options visible by default")
    func cliCustomVisibilityUsesAvailableCatalog() {
        let catalog = [
            CLIOptionConfig(
                id: "--model", label: "Model", description: "Model",
                isAvailable: false, isDefaultEnabled: false
            ),
            CLIOptionConfig(
                id: "--continue", label: "Continue", description: "Continue",
                isAvailable: true, isDefaultEnabled: false
            ),
            CLIOptionConfig(
                id: "--resume", label: "Resume", description: "Resume",
                isAvailable: true, isDefaultEnabled: false
            ),
        ]

        let visible = NewPaneSheet.defaultVisibleCLIOptions(catalog: catalog, profile: nil)

        #expect(visible.map(\.id) == ["--continue", "--resume"])
    }

    @Test("Environment visibility includes enabled and show-on-pane-create profile variables")
    func environmentVisibilityIncludesEnabledAndShownVariables() {
        let catalog = [
            EnvVarConfig(
                id: "ANTHROPIC_API_KEY", label: "API key", description: "API key",
                isAvailable: false
            ),
            EnvVarConfig(
                id: "ANTHROPIC_MODEL", label: "Model", description: "Model",
                isAvailable: true
            ),
            EnvVarConfig(
                id: "ANTHROPIC_BASE_URL", label: "Base URL", description: "Base URL",
                isAvailable: true
            ),
        ]
        let profile = Profile(
            name: "Environment Visibility",
            harness: .claude,
            envVars: [
                ProfileEnvVar(id: "ANTHROPIC_API_KEY", isEnabled: true, value: "key"),
                ProfileEnvVar(
                    id: "ANTHROPIC_MODEL", isEnabled: false, value: "model",
                    showOnPaneCreate: true
                ),
                ProfileEnvVar(id: "ANTHROPIC_BASE_URL", isEnabled: false, value: "url"),
            ]
        )

        let visible = NewPaneSheet.defaultVisibleEnvVars(catalog: catalog, profile: profile)

        #expect(visible.map(\.id) == ["ANTHROPIC_API_KEY", "ANTHROPIC_MODEL"])
    }

    @Test("Environment custom pane keeps available variables visible by default")
    func environmentCustomVisibilityUsesAvailableCatalog() {
        let catalog = [
            EnvVarConfig(
                id: "ANTHROPIC_API_KEY", label: "API key", description: "API key",
                isAvailable: false
            ),
            EnvVarConfig(
                id: "ANTHROPIC_MODEL", label: "Model", description: "Model",
                isAvailable: true
            ),
            EnvVarConfig(
                id: "ANTHROPIC_BASE_URL", label: "Base URL", description: "Base URL",
                isAvailable: true
            ),
        ]

        let visible = NewPaneSheet.defaultVisibleEnvVars(catalog: catalog, profile: nil)

        #expect(visible.map(\.id) == ["ANTHROPIC_MODEL", "ANTHROPIC_BASE_URL"])
    }
}
