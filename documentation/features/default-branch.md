# Default branch (Settings)

The **General → Git** section in Settings exposes a **Default Branch** toggle and optional **branch name** field. Values are persisted so they survive app restarts.

## Configuration

Open **Settings → General**. In the **Git** section:

- **Default Branch** — Checkbox-style toggle. When on, the branch name field is shown. Persisted to `default-branch.json` when changed.
- **Branch Name** — Short name such as `main`, `master`, or `develop`. Default in code is `main`.

Accessibility identifiers: `settings-default-branch-toggle`, `settings-default-branch-field`.

## Persistence

Settings are stored in:

`~/Library/Application Support/agent-session-manager/default-branch.json`

Implementation: `SettingsPersistence.saveDefaultBranch` / load on startup in `AppSettings`.

## Relationship to New Pane (Claude) worktrees

[worktree-creation.md](worktree-creation.md) documents how **Claude Code** panes resolve input: `classifyClaudePaneIntent`, `peekExistingResolvedWorktree`, and `resolveOrAttachWorktree` (including `git fetch origin <ref>` when creating a new managed tree).

That resolution path uses **what you type in the New Pane field** and Git’s view of the repo. It does **not** currently read `defaultBranch` or `isDefaultBranchEnabled` from `AppSettings` when attaching or creating worktrees. So the Settings copy describes a **stored preference** for the product; end-to-end wiring of that preference into `Tab` worktree creation is not implemented in the current codebase. For accurate behavior of Claude panes, rely on [worktree-creation.md](worktree-creation.md).
