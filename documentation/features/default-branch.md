# Default Branch

The default branch feature automates worktree creation from a configured base branch.

## How It Works

When creating a new pane with a specific branch name, the app:

1. Fetches the configured default branch from `origin` so the worktree starts from up-to-date code.
2. Attempts to add a worktree from the specified branch.
3. If the branch doesn't exist locally or on origin, creates it from the default branch.

## Configuration

Open **Settings > General** > **Git**.

**Default Branch toggle** — Enable or disable the feature entirely. Enabled by default.

**Branch Name** (visible only when enabled) — The branch to use as the base. Default is `main`. Common values: `main`, `master`, `develop`.

When disabled, worktrees are created from the current `HEAD` instead of a specific base branch.

## Persistence

Settings are stored in `~/Library/Application Support/agent-session-manager/default-branch.json`.
