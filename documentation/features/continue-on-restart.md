# Continue on Restart

When the app relaunches and restores a saved session, Claude panes automatically pass `--continue` to the CLI so each conversation picks up where it left off. Codex panes are unaffected.

## Configuration

Open **Settings → General**. In the **Sessions** section:

- **Continue on Restart** — Checkbox toggle. Default: on. Persisted to `restart-settings.json` when changed.

Accessibility identifier: `settings-continue-on-restart-toggle`.

## Behavior

When enabled, `SessionPersistence.restore` passes `extraArgs: ["--continue"]` to `tab.addPane` for every Claude pane. This applies to both app-managed worktrees and external checkout panes. The flag is never passed to Codex panes regardless of the setting.

## Persistence

Setting stored at:

`~/Library/Application Support/agent-session-manager/restart-settings.json`

Implemented via `SettingsPersistence.saveRestartSettings` / `SettingsPersistence.restoreRestartSettings`, loaded in `ContentView` before `SessionPersistence.restore`.

## Lost Pane Fix

Panes added via the New Pane sheet are now immediately persisted to `sessions.json`. Previously, only tab additions and active-tab changes triggered a save, so a pane added right before quitting would be lost on relaunch.
