# Continue on Restart

When the app relaunches and restores a saved session, Claude and Cursor panes automatically pass `--continue` to the CLI so each conversation picks up where it left off. OpenCode uses its saved session ID when available, with `--continue` as a fallback. Codex panes are unaffected.

## Configuration

Open **Settings → Panes → Cleanup**:

- **Continue on Restart** — Checkbox toggle. Default: on. Persisted to `restart-settings.json` when changed.

Accessibility identifier: `settings-continue-on-restart-toggle`.

## Behavior

When enabled, `SessionPersistence.restore` adds `--continue` to Claude and Cursor pane arguments unless the saved options already contain `--continue` or an explicit `--resume`. This applies to both app-managed worktrees and external checkout panes. The flag is never added to Codex panes regardless of the setting.

## Persistence

Setting stored at:

`~/Library/Application Support/agent-session-manager/restart-settings.json`

Implemented via `SettingsPersistence.saveRestartSettings` / `SettingsPersistence.restoreRestartSettings`, loaded in `ContentView` before `SessionPersistence.restore`.

## Lost Pane Fix

Panes added via the New Pane sheet are now immediately persisted to `sessions.json`. Previously, only tab additions and active-tab changes triggered a save, so a pane added right before quitting would be lost on relaunch.
