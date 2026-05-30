# Default Branch

Settings → Panes → New Pane exposes a **Default Branch** toggle and branch-name field. The values are persisted to:

`~/Library/Application Support/agent-session-manager/default-branch.json`

## Behavior

The setting is wired into the shared New Pane worktree flow for Claude Code, Cursor, Codex, and OpenCode.

- When enabled, a plain name that does not resolve to an existing checkout or ref creates a new linked worktree from the configured default branch.
- When disabled, unresolved input fails with a ref-not-found error.
- The default branch name is `main`.

The **Starting Point** setting controls whether fallback creation starts from freshly fetched `origin/<default-branch>` or local `HEAD`.

Implementation: `NewPaneSheet.create`, `Tab.resolveOrAttachWorktree`, and `SettingsPersistence.saveDefaultBranch` / `restoreDefaultBranch`.

See [worktree-creation.md](worktree-creation.md) for the full resolution order.
