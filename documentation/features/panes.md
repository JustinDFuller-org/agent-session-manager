# Panes

A **pane** is a terminal session inside a tab. Each pane runs an AI agent CLI (Claude Code or Codex). For Claude Code, the app can attach to existing git checkouts or create **managed** trees under `.agent-session-manager/worktrees/<name>` inside the tab’s repository—see [worktree-creation.md](worktree-creation.md) for the full routing behavior.

## Creating a pane

Use **⌘P** (default; configurable under **Settings → Shortcuts → New Pane in Current Tab**) or **File → New Pane in Current Tab** to open the New Pane sheet.

### Fields

**CLI** — Pick the tool to launch. Only tools enabled in **Settings → Tools** appear.

**Claude Code — single text field** — One input covers session name, branch/ref, or reuse of an existing worktree path. Classification and confirmation dialogs are described in [worktree-creation.md](worktree-creation.md). There is no separate “branch” row in the sheet.

**Codex — session name** — A short identifier for the pane. Git worktree resolution does not apply.

**CLI options** — Flags enabled in **Settings → CLI Options** appear as toggles and fields. Options marked default-on in Settings start checked.

Choose **Open** or press Return to create the pane.

## Status line

Each pane shows a configurable status bar at the bottom (model, cost, context usage, worktree name, and more). Configure items in **Settings → Status Line**.

## Session persistence

Open panes are saved to `~/Library/Application Support/agent-session-manager/sessions.json`. On relaunch, the app restores tabs and restarts the CLI in any pane whose checkout still exists on disk (see restore rules in [worktree-creation.md](worktree-creation.md)).

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘T (default) | New tab |
| ⌘P (default) | New pane in current tab |
| ⌘W | Close active pane |
| ⌘K | Close active tab |
| ⌘1–⌘9 | Switch to tab by index |

For **default branch** settings (stored in Settings but not the same as per-ref resolution in the New Pane flow), see [default-branch.md](default-branch.md).
