# Default Branch

Settings → Panes → New Pane exposes a **Default Branch** toggle and branch-name field. The values are persisted to:

`~/Library/Application Support/agent-session-manager/default-branch.json`

## Behavior

The setting is wired into the shared New Pane worktree flow for Claude Code, Cursor, and Codex.

- When enabled, a plain name that does not resolve to an existing checkout or ref creates a new linked worktree from the configured default branch.
- When disabled, unresolved input fails with a ref-not-found error.
- The default branch name is `main`.

The **Starting Point** setting controls whether fallback creation starts from freshly fetched `origin/<default-branch>` or local `HEAD`.

Implementation: `NewPaneSheet.create`, `Tab.resolveOrAttachWorktree`, and `SettingsPersistence.saveDefaultBranch` / `restoreDefaultBranch`.

See [worktree-creation.md](worktree-creation.md) for the full resolution order.

## Per-Tab Base Branch Override

Each tab can carry its own base branch via the **Base Branch** field in the New Tab sheet (File → New Tab, or ⌘T).

- **Set at creation time only.** Leaving the field blank means the tab inherits the global default branch.
- **Override takes precedence over the global toggle.** When a tab has a non-empty `baseBranchOverride`, that branch is used as the worktree base even if the global Default Branch toggle is off.
- **Persisted per tab** in `sessions.json` under `baseBranchOverride`. Legacy sessions without the key decode as `nil` (global default applies).
- **Telemetry** — every pane creation emits a `tab.worktree.base_branch_resolved` span with `base.branch` and `base.branch.source` (`tab-override` | `global-default` | `none`).

**Data flow:** `Tab.baseBranchOverride` → read in `NewPaneSheet.create()` → passed as `defaultBranch:` to `Tab.resolveOrAttachWorktree`.
