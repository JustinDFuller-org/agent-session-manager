# First-Launch Setup Wizard

On true first launch the app shows a three-step wizard that configures the shell and detects installed CLI tools. It runs exactly once, gated by `hasCompletedOnboarding` in `AppSettings`.

## Steps

### 1. Welcome / Consent
Brief explanation of what the wizard does. **Set Up** proceeds; **Skip** marks onboarding complete and leaves defaults untouched (Claude only, auto-detect shell).

### 2. Shell
Shows the auto-detected shell (`$SHELL` env var, fallback `/bin/zsh`). The user can:
- Keep **Auto-detect** (empty `preferredShell`)
- Pick a known shell from `ShellResolver.commonShells`
- Enter a custom path via **Other…**

The selection is persisted in `shell-settings.json` as `preferredShell`.

### 3. Tools
Runs `CLIToolDetector.detectInstalled(shell:)` in the user's chosen interactive shell (`-i -c "which <binary>"`). Each `CLIType` (claude, codex, cursor/agent, opencode) is probed concurrently. Detected tools appear pre-checked; the user may toggle. **Done** enables all checked tools (additive — never removes existing active tools). If nothing is checked and no tools were already active, Claude is force-enabled as a fallback.

## Persistence files

| File | Contents |
|---|---|
| `shell-settings.json` | `{"preferredShell": "/bin/bash"}` — empty string = auto-detect |
| `onboarding-settings.json` | `{"completed": true}` |

Both files are written under the Application Support subdirectory (`agent-session-manager` / `agent-session-manager.dev`).

## Re-running detection / changing the shell

In **Settings ▸ General**, the **Shell** section exposes the same picker to change the preferred shell after onboarding. Tool auto-detection runs only during the onboarding wizard; there is no persistent "Detect Installed Tools" button in Settings.

## Key classes

- `ShellResolver` — static helpers: `detectedLoginShell()`, `resolved(_:)`, `commonShells`
- `CLIToolDetector` — `detectInstalled(shell:runner:)` async, injectable runner for unit tests
- `OnboardingWizardView` — multi-step sheet, presented from `ContentView`
- `SettingsPersistence.saveShellSettings` / `restoreShellSettings`
- `SettingsPersistence.saveOnboarding` / `restoreOnboarding`

## UI-test gating

The wizard is suppressed when `AgentSessionManagerApp.isUITesting` is true (i.e. `--uitesting` launch arg). To force it in a dedicated test, add `--uitesting-show-onboarding`. All existing UI tests are unaffected.

## State clearing

`make reset-app-state` and `make reset-app-state-dev` delete both `shell-settings.json` and `onboarding-settings.json`. `UITests/Helpers/BaseTestCase.clearPersistedState()` does the same for the test App Support directory.
