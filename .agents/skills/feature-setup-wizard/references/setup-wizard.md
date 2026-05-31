# Setup Wizard Feature Reference

See [documentation/features/setup-wizard.md](../../../../documentation/features/setup-wizard.md) for the full feature documentation.

## Critical files

- `Sources/AgentSessionManager/Models/AppSettings.swift` — `preferredShell`, `hasCompletedOnboarding`
- `Sources/AgentSessionManager/Models/CLIOptionConfig.swift` — `recommendedDefaults(for:)` factory (per-tool recommended flag set for wizard step)
- `Sources/AgentSessionManager/Models/EnvVarConfig.swift` — `recommendedDefaults()` factory (recommended Claude env vars for wizard step)
- `Sources/AgentSessionManager/Models/StatusLineConfig.swift` — `wizardDefault()` factory (three-row spec for wizard step)
- `Sources/AgentSessionManager/Controllers/ShellResolver.swift` — shell detection and resolution
- `Sources/AgentSessionManager/Controllers/CLIToolDetector.swift` — async tool detection
- `Sources/AgentSessionManager/Controllers/SettingsPersistence.swift` — `saveShellSettings`, `restoreShellSettings`, `saveStatusLine`, `restoreStatusLine`, `saveOnboarding`, `restoreOnboarding`, `save`/`restore` (Claude CLI), `saveEnvVarOptions`/`restoreEnvVarOptions`
- `Sources/AgentSessionManager/Controllers/TerminalController.swift` — `pendingShell` property
- `Sources/AgentSessionManager/Models/Tab.swift` — threads `appSettings` through `addPane`, `completeSetup`, `refreshPaneWithArgs`, `openShellPane`; copies `pendingShell` in `restartPane`, `refreshPane`, `openShellInPane`
- `Sources/AgentSessionManager/Views/OnboardingWizardView.swift` — multi-step wizard sheet (welcome / shell / tools / statusLine / cliFlags / profiles steps); per-step draft state; Save/Skip/Finish wiring; Clear/Reset toggle on each draft
- `Sources/AgentSessionManager/Views/StatusLineSettingsViews.swift` — `StatusLineConfigLayoutEditor` reused in the status line wizard step
- `Sources/AgentSessionManager/Views/SettingsView.swift` — `CLIOptionsContent` (internal) reused in the CLI flags wizard step; Shell section + Detect button in `ToolsContent`
- `Sources/AgentSessionManager/Views/ProfileSettingsViews.swift` — `ProfilesContent` reused in the profiles wizard step; `profile-new-button` accessibility identifier
- `Sources/AgentSessionManager/App.swift` — restores + `showOnboarding` trigger
- `UITests/OnboardingWizardTests.swift` — UI tests (includes CLI flags and profiles step tests)
- `Tests/ShellResolverTests.swift`, `Tests/CLIToolDetectorTests.swift`, `Tests/SettingsPersistenceOnboardingTests.swift`, `Tests/StatusLineConfigWizardDefaultTests.swift`, `Tests/CLIOptionConfigRecommendedDefaultsTests.swift`, `Tests/EnvVarConfigRecommendedDefaultsTests.swift` — unit tests

## Step order

`welcome → shell → tools → statusLine → cliFlags → profiles (finish)`

## Persistence files

- `shell-settings.json` — `{"preferredShell": ""}` 
- `onboarding-settings.json` — `{"completed": false}`
- `statusline-settings.json` — written by wizard on Save; see status-line feature for schema
- `settings.json` — Claude CLI options (written by CLI Flags Save)
- `env-var-settings.json` — Claude env vars (written by CLI Flags Save)

## UI-test gating

- Wizard suppressed when `--uitesting` arg present (no `--uitesting-show-onboarding`)
- Force wizard in tests: `--uitesting-show-onboarding`

## Recommended defaults factories

- `CLIOptionConfig.recommendedDefaults(for: .claude)` → marks `--continue`, `--resume`, `--model`, `--permission-mode` available
- `CLIOptionConfig.recommendedDefaults(for: .codex)` → marks `--model`, `--ask-for-approval`, `--sandbox`, `--search` available
- `CLIOptionConfig.recommendedDefaults(for: .cursor)` → marks `--model`, `--resume`, `--mode` available
- `EnvVarConfig.recommendedDefaults()` → marks `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, `ANTHROPIC_BASE_URL` available
