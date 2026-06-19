# First-Launch Setup Wizard

On true first launch the app shows a six-step wizard that configures the shell, detects installed CLI tools, pre-populates the status line, sets recommended CLI flags, and introduces profiles. It runs exactly once, gated by `hasCompletedOnboarding` in `AppSettings`.

The wizard uses two presentation sizes. `welcome`, `shell`, and `tools` stay compact (`520pt` wide, `320pt` minimum height, `360pt` ideal height). `statusLine` and `profiles` switch to a larger editor-sized sheet (`760pt` minimum and ideal width, `700pt` minimum and ideal height), while `cliFlags` uses the same width with a `720pt` minimum and ideal height so its segmented tool picker, recommended-flag editor, and footer all stay visible. For those expanded steps, the sheet height is measured from the full step layout, including the bottom action row, so `Save`, `Skip`, and `Finish` stay visible and clickable without scrolling or keyboard fallbacks.

## Steps

### 1. Welcome / Consent
Brief explanation of what the wizard does. **Set Up** proceeds; **Skip** marks onboarding complete and leaves defaults untouched (Claude only, auto-detect shell, single-row catalog default for the status line).

### 2. Shell
Shows the auto-detected shell (`$SHELL` env var, fallback `/bin/zsh`). The user can:
- Keep **Auto-detect** (empty `preferredShell`)
- Pick a known shell from `ShellResolver.commonShells`
- Enter a custom path via **Other…**

The selection is persisted in `shell-settings.json` as `preferredShell` when **Continue** is clicked.

### 3. Tools
Runs `CLIToolDetector.detectInstalled(shell:)` in the user's chosen interactive shell (`-i -c "which <binary>"`). Each `CLIType` (claude, codex, cursor/agent) is probed concurrently. Detected tools appear pre-checked; the user may toggle. **Continue** persists active tools and advances to the Status Line step.

### 4. Status Line
Pre-fills the three-row wizard default layout (see `StatusLineConfig.wizardDefault()`):
- Row 1: `pr`, `profileName`, `model`
- Row 2: `context`, `contextRemaining`, `inputTokens`, `outputTokens`
- Row 3: `worktree`, `linesAdded`, `linesRemoved`

The user can edit inline via `StatusLineConfigLayoutEditor`. When the draft equals `wizardDefault()`, a **Clear** button empties all rows so the user can start from scratch; once the layout diverges from the default, the button becomes **Reset to Default** and restores the three-row spec. **Save** persists the draft to `statusline-settings.json` and advances to CLI Flags. **Skip** clears all rows (empty `rows` array = no status bar rendered), persists, and advances to CLI Flags.

During onboarding this step gets a `420pt` minimum editor viewport inside the expanded sheet so the grouped status-line controls are visible without hunting through a cramped inner scroll area, while the `Save` / `Skip` footer remains in the measured sheet body.

The wizard default layout is distinct from the catalog default (`StatusLineConfig()` — single row: model, worktree, cost, context). The catalog default remains the fallback for code paths that skip the wizard.

### 5. CLI Flags
Surfaces the most-used CLI options for the enabled tools so they appear in the New Pane sheet. Recommended defaults are seeded by `CLIOptionConfig.recommendedDefaults(for:)` and `EnvVarConfig.recommendedDefaults()`:

| Tool | Recommended flags |
|---|---|
| Claude Code | `--continue`, `--resume`, `--model`, `--permission-mode` |
| Codex | `--model`, `--ask-for-approval`, `--sandbox`, `--search` |
| Cursor | `--model`, `--resume`, `--mode` |
Claude also recommends three env vars: `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, `ANTHROPIC_BASE_URL`.

A **Clear** button (shown when draft equals recommended) sets all flags unavailable. Once the draft diverges, it becomes **Reset to Recommended**. A segmented tool picker appears when multiple tools are enabled.

During onboarding this step gets a `440pt` minimum editor viewport inside the expanded sheet so the recommended flag rows and Claude environment variable controls render at their intended width, with the `Save` / `Skip` footer still visible at the bottom of the sheet.

**Save** writes each enabled tool's options plus env vars to their respective persistence files and advances to Profiles. **Skip** advances without persisting.

### 6. Profiles (final)
Embeds `ProfilesContent` (the full profile manager) so new users can create named flag/env-var bundles. Creating a profile is optional. **Finish** sets `hasCompletedOnboarding = true`, persists it, and dismisses the wizard.

During onboarding this step gets a `420pt` minimum editor viewport inside the expanded sheet so the profile list and New Profile action are immediately usable, with the `Finish` button visible in the same measured layout.

## Per-step persistence

Settings are saved as the user advances through each step:

| Step | Saved on | File |
|---|---|---|
| Shell | **Continue** | `shell-settings.json` |
| Tools | **Continue** | `active-tools-settings.json` |
| Status Line | **Save** / **Skip** | `statusline-settings.json` |
| CLI Flags | **Save** | per-tool settings files (see below) |
| Profiles | **Finish** | `onboarding-settings.json` |

## Persistence files

| File | Contents |
|---|---|
| `shell-settings.json` | `{"preferredShell": "/bin/bash"}` — empty string = auto-detect |
| `onboarding-settings.json` | `{"completed": true}` |
| `statusline-settings.json` | Status line config written on **Save**; see [status-line.md](status-line.md) for schema |
| `settings.json` | Claude CLI options (written on CLI Flags **Save**) |
| `codex-settings.json` | Codex CLI options |
| `cursor-settings.json` | Cursor CLI options |
| `env-var-settings.json` | Claude env var options |

All files are written under the Application Support subdirectory (`agent-session-manager` / `agent-session-manager.dev`).

## Re-running detection / changing the shell

In **Settings ▸ General**, the **Shell** section exposes the same picker to change the preferred shell after onboarding. Tool auto-detection runs only during the onboarding wizard; there is no persistent "Detect Installed Tools" button in Settings.

## Key classes

- `ShellResolver` — static helpers: `detectedLoginShell()`, `resolved(_:)`, `commonShells`
- `CLIToolDetector` — `detectInstalled(shell:runner:)` async, injectable runner for unit tests
- `OnboardingWizardView` — multi-step sheet (welcome / shell / tools / statusLine / cliFlags / profiles steps), presented from `ContentView`
- `StatusLineConfig.wizardDefault()` — three-row spec used by the wizard status line step
- `CLIOptionConfig.recommendedDefaults(for:)` — per-tool recommended flag set used by the wizard CLI flags step
- `EnvVarConfig.recommendedDefaults()` — recommended Claude env var set used by the wizard CLI flags step
- `CLIOptionsContent` (internal, in `SettingsView.swift`) — reusable flag editor embedded in the CLI flags step
- `ProfilesContent` (in `ProfileSettingsViews.swift`) — full profile manager embedded in the profiles step
- `SettingsPersistence.saveShellSettings` / `restoreShellSettings`
- `SettingsPersistence.saveStatusLine` / `restoreStatusLine`
- `SettingsPersistence.saveOnboarding` / `restoreOnboarding`
- `SettingsPersistence.save` / `restore` (Claude CLI options)
- `SettingsPersistence.saveEnvVarOptions` / `restoreEnvVarOptions`

## UI-test gating

The wizard is suppressed when `AgentSessionManagerApp.isUITesting` is true (i.e. `--uitesting` launch arg). To force it in a dedicated test, add `--uitesting-show-onboarding`. All existing UI tests are unaffected.

## Accessibility identifiers

| Identifier | Element |
|---|---|
| `onboarding-skip-button` | Welcome Skip |
| `onboarding-setup-button` | Welcome Set Up |
| `onboarding-shell-picker` | Shell picker |
| `onboarding-shell-custom-field` | Custom shell path field |
| `onboarding-shell-continue-button` | Shell Continue |
| `onboarding-tool-toggle-<rawValue>` | Per-tool checkbox |
| `onboarding-done-button` | Tools Continue |
| `onboarding-statusline-clear-button` | Status Line Clear |
| `onboarding-statusline-reset-button` | Status Line Reset to Default |
| `onboarding-statusline-skip-button` | Status Line Skip |
| `onboarding-statusline-save-button` | Status Line Save |
| `onboarding-cliflags-tool-picker` | CLI Flags tool picker (segmented) |
| `onboarding-cliflags-clear-button` | CLI Flags Clear |
| `onboarding-cliflags-reset-button` | CLI Flags Reset to Recommended |
| `onboarding-cliflags-skip-button` | CLI Flags Skip |
| `onboarding-cliflags-save-button` | CLI Flags Save |
| `onboarding-profiles-finish-button` | Profiles Finish |
| `profile-new-button` | New Profile button in ProfilesContent |

## State clearing

`make reset-app-state` and `make reset-app-state-dev` delete `shell-settings.json`, `onboarding-settings.json`, and `statusline-settings.json`. `UITests/Helpers/BaseTestCase.clearPersistedState()` does the same for the test App Support directory.
