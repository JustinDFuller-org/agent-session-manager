# Panes

A **pane** is a terminal session inside a tab. Each pane runs an AI agent CLI (Claude Code or Codex) in an isolated git worktree, so multiple agents can work in parallel without interfering with each other.

## Creating a Pane

Press **⌘P** (or use File → New Pane in Current Tab) to open the New Pane sheet.

### Fields

**CLI** — Select which tool to launch. Only tools enabled in Settings → Tools appear here.

**Branch (optional, Claude only)** — The git branch to base the worktree on. Leave empty to open a pane in the tab's root directory without creating a worktree.

**Session Name** — A short identifier for the pane (letters, digits, dots, underscores, dashes). This becomes the worktree directory name under `.tree/<name>`.

**CLI Options** — Flags enabled in Settings → CLI Options appear here as toggles. Pre-checked flags are those marked "Default on" in Settings.

Press **Open** or hit Return to create the pane.

## Worktree Setup

When you specify a branch, the app creates a git worktree at `<tab-directory>/.tree/<session-name>` before launching the agent. The setup logic:

1. Fetches the configured default branch from `origin` so the worktree starts from up-to-date code.
2. Attempts `git worktree add .tree/<name> <branch>`.
3. If the branch is already checked out in another worktree, that worktree is reused.
4. If the branch exists on origin but not locally, it is fetched and checked out.
5. If the branch doesn't exist anywhere, it is created from `origin/<default-branch>` so new work always starts from the latest main-line code.

## Up-to-Date with Default Branch

New worktrees are always based on the latest code from your configured default branch. This ensures agents start from an up-to-date baseline rather than a stale local state.

### Configuring the Default Branch

Open **Settings → General** and set **Default Branch** to the branch name your repository uses (e.g., `main`, `master`, `develop`). The default is `main`.

The app fetches this branch from `origin` each time a new worktree is created. If the machine is offline or no remote is configured, the fetch is silently skipped.

## Status Line

Each pane shows a configurable status bar at the bottom, populated with data from the Claude session (model, cost, context usage, worktree name, and more). Configure visible items in **Settings → Status Line**.

## Session Persistence

Open panes are saved to `~/Library/Application Support/agent-session-manager/sessions.json`. When the app relaunches, it restores tabs and restarts the agent CLI in any pane whose worktree still exists on disk.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘P | New pane in current tab |
| ⌘W | Close active pane |
| ⌘1–⌘9 | Switch to tab by index |
