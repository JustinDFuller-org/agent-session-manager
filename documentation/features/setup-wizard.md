# First-Launch Setup Wizard

On true first launch the app shows a four-step wizard that configures the shell, detects installed CLI tools, and pre-populates the status line. It runs exactly once, gated by `hasCompletedOnboarding` in `AppSettings`.

## Steps

### 1. Welcome / Consent
Brief explanation of what the wizard does. **Set Up** proceeds; **Skip** marks onboarding complete and leaves defaults untouched (Claude only, auto-detect shell, single-row catalog default for the status line).

### 2. Shell
Shows the auto-detected shell (`$SHELL` env var, fallback `/bin/zsh`). The user can:
- Keep **Auto-detect** (empty `preferredShell`)
- Pick a known shell from `ShellResolver.commonShells`
- Enter a custom path via **Other…**

The selection is persisted in `shell-settings.json` as `preferredShell`.

### 3. Tools
Runs `CLIToolDetector.detectInstalled(shell:)` in the user's chosen interactive shell (`-i -c "which <binary>"`). Each `CLIType` (claude, codex, cursor/agent, opencode) is probed concurrently. Detected tools appear pre-checked; the user may toggle. **Continue** proceeds to the Status Line step.

### 4. Status Line
Pre-fills the three-row wizard default layout (see `StatusLineConfig.wizardDefault()`):
- Row 1: `pr`, `profileName`, `model`
- Row 2: `context`, `contextRemaining`, `inputTokens`, `outputTokens`
- Row 3: `worktree`, `linesAdded`, `linesRemoved`

The user can edit inline via `StatusLineConfigLayoutEditor`. When the draft equals `wizardDefault()`, a **Clear** button empties all rows so the user can start from scratch; once the layout diverges from the default, the button becomes **Reset to Default** and restores the three-row spec. **Save** writes the draft to `statusline-settings.json` and completes onboarding. **Skip** clears all rows (empty `rows` array = no status bar rendered) and completes onboarding.

The wizard default layout is distinct from the catalog default (`StatusLineConfig()` — single row: model, worktree, cost, context). The catalog default remains the fallback for code paths that skip the wizard.

## Persistence files

| File | Contents |
|---|---|
| `shell-settings.json` | `{"preferredShell": "/bin/bash"}` — empty string = auto-detect |
| `onboarding-settings.json` | `{"completed": true}` |
| `statusline-settings.json` | Status line config written on **Save**; see [status-line.md](status-line.md) for schema |

All files are written under the Application Support subdirectory (`agent-session-manager` / `agent-session-manager.dev`).

## Re-running detection / changing the shell

In **Settings ▸ General**, the **Shell** section exposes the same picker to change the preferred shell after onboarding. Tool auto-detection runs only during the onboarding wizard; there is no persistent "Detect Installed Tools" button in Settings.

## Key classes

- `ShellResolver` — static helpers: `detectedLoginShell()`, `resolved(_:)`, `commonShells`
- `CLIToolDetector` — `detectInstalled(shell:runner:)` async, injectable runner for unit tests
- `OnboardingWizardView` — multi-step sheet (welcome / shell / tools / statusLine), presented from `ContentView`
- `StatusLineConfig.wizardDefault()` — three-row spec used by the wizard status line step
- `SettingsPersistence.saveShellSettings` / `restoreShellSettings`
- `SettingsPersistence.saveStatusLine` / `restoreStatusLine`
- `SettingsPersistence.saveOnboarding` / `restoreOnboarding`

## UI-test gating

The wizard is suppressed when `AgentSessionManagerApp.isUITesting` is true (i.e. `--uitesting` launch arg). To force it in a dedicated test, add `--uitesting-show-onboarding`. All existing UI tests are unaffected.

## State clearing

`make reset-app-state` and `make reset-app-state-dev` delete `shell-settings.json`, `onboarding-settings.json`, and `statusline-settings.json`. `UITests/Helpers/BaseTestCase.clearPersistedState()` does the same for the test App Support directory.
