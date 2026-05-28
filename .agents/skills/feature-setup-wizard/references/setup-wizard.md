# Setup Wizard Feature Reference

See [documentation/features/setup-wizard.md](../../../../documentation/features/setup-wizard.md) for the full feature documentation.

## Critical files

- `Sources/AgentSessionManager/Models/AppSettings.swift` — `preferredShell`, `hasCompletedOnboarding`
- `Sources/AgentSessionManager/Controllers/ShellResolver.swift` — shell detection and resolution
- `Sources/AgentSessionManager/Controllers/CLIToolDetector.swift` — async tool detection
- `Sources/AgentSessionManager/Controllers/SettingsPersistence.swift` — `saveShellSettings`, `restoreShellSettings`, `saveOnboarding`, `restoreOnboarding`
- `Sources/AgentSessionManager/Controllers/TerminalController.swift` — `pendingShell` property
- `Sources/AgentSessionManager/Models/Tab.swift` — threads `appSettings` through `addPane`, `completeSetup`, `refreshPaneWithArgs`, `openShellPane`; copies `pendingShell` in `restartPane`, `refreshPane`, `openShellInPane`
- `Sources/AgentSessionManager/Views/OnboardingWizardView.swift` — multi-step wizard sheet
- `Sources/AgentSessionManager/Views/SettingsView.swift` — Shell section + Detect button in `ToolsContent`
- `Sources/AgentSessionManager/App.swift` — restores + `showOnboarding` trigger
- `UITests/OnboardingWizardTests.swift` — UI tests
- `Tests/ShellResolverTests.swift`, `Tests/CLIToolDetectorTests.swift`, `Tests/SettingsPersistenceOnboardingTests.swift` — unit tests

## Persistence files

- `shell-settings.json` — `{"preferredShell": ""}` 
- `onboarding-settings.json` — `{"completed": false}`

## UI-test gating

- Wizard suppressed when `--uitesting` arg present (no `--uitesting-show-onboarding`)
- Force wizard in tests: `--uitesting-show-onboarding`
