# Worktree creation and New Pane (Claude)

This document describes how Agent Session Manager places git worktrees on disk, how the **New Pane** sheet behaves for Claude Code sessions, and how errors are surfaced. It is the reference for users and contributors working on `Tab`, `NewPaneSheet`, `Pane`, or session restore.

## Why this path exists

New worktrees created **by Agent Session Manager** (when you attach to a branch that is not yet checked out) are placed only under the **tab’s repo root** at:

**`.agent-session-manager/worktrees/<name>`**

That mirrors Claude Code’s convention of using **`.claude/worktrees/`** under a project: the directory makes it obvious which tool owns the trees the app creates, and `.agent-session-manager/` can later hold other app-specific data beside `worktrees/`. **No other files or subfeatures are written there in the current release**—only the per-worktree directories git links.

For those **managed** checkouts, the short `<name>` is the same identifier passed to `claude --worktree '<name>'`. On disk, the full checkout is at `<repo>/.agent-session-manager/worktrees/<name>`.

**Existing** git worktrees for the same repository may live anywhere on disk (sibling folders, `.claude/worktrees/`, etc.). If `git worktree list` shows a branch you ask for, Agent Session Manager can open that checkout: it sets the terminal’s working directory to that path and runs `claude` **without** `--worktree`, matching the usual pattern of `cd <checkout> && claude` for manually added worktrees.

## New Pane: two modes (Claude only)

When the CLI is **Claude Code**:

1. **Default — “Existing branch or worktree” is off**  
   You enter a **Session name** (letters, digits, `.`, `_`, `-` only). The app does **not** run `git worktree add` in this path; it starts Claude with `claude --worktree '<name>'` from the tab directory. Claude may create or use its own layout; the sheet’s path hint shows where the app’s managed worktrees live for consistency.

2. **“Existing branch or worktree” is on**  
   The Session name field is **hidden**. You enter a single **branch, ref, or managed worktree name** (`main`, `origin/feature`, or a folder name under `.agent-session-manager/worktrees/<name>`, etc.). The app resolves that input (see below), then opens a pane. The pane title is the short managed name or the **last path segment** of an existing checkout elsewhere. All git setup runs in Swift (`Foundation.Process`); failures appear in the sheet, never as extra shell noise in the terminal.

When the CLI is **Codex**, only the Session name field is shown; worktree resolution does not apply.

## Resolution order (toggle on)

Implementation lives in `Tab.resolveOrAttachWorktree(userRef:)`, which returns a `ResolvedWorktree` (`paneTitle`, optional process-directory override, `checkoutURL`). At a high level:

1. **Trim** the input. If it is a **valid worktree name** and `<repo>/.agent-session-manager/worktrees/<input>` already exists and looks like a **linked git worktree** (a `.git` *file* with `gitdir:`), that name is used as a managed resolution.

2. **`git worktree list --porcelain`** is parsed. A listing whose **worktree path’s last segment** equals your input is chosen first (so `…/worktree-meter-chore-claude-review` wins over another checkout whose *branch name* is also `worktree-meter-chore-claude-review`).
3. Otherwise the first listing whose **branch** matches the input (short name, `refs/heads/…`, `refs/remotes/…`, `origin/…`-style):
   - If that entry’s path is **under** `<repo>/.agent-session-manager/worktrees/`, the **final path segment** is the managed short name (`claude --worktree` from the repo root).
   - Otherwise the app **reuses** that checkout: process `cwd` is that path, the Claude command **omits** `--worktree`. Paths reported by `git worktree list` are trusted (including the main repo checkout, where `.git` is a directory).

4. Otherwise the app picks a **derived folder name** from the ref (last path segment, sanitized), verifies the ref with `git rev-parse`, runs **`git fetch origin <ref>`** if needed, creates **`.agent-session-manager`** if needed, and runs **`git worktree add .agent-session-manager/worktrees/<n> <ref>`** (only this path is used for **new** trees). If `worktree add` fails because the branch is already checked out, the list is consulted again so a managed or external checkout can be returned.

Duplicate panes in the same tab are detected by **checkout directory** (not only by displayed name).

## Session restore

`SessionPersistence` restores Claude panes when the checkout still exists:

- **`claudeProcessDirectory` set** in `sessions.json`: that absolute path must still exist.
- Otherwise the **managed** path `<tab-dir>/.agent-session-manager/worktrees/<name>`, or legacy `<tab-dir>/.tree/<name>`.

So old sessions can still restore if only the legacy path exists; reused external checkouts persist via `claudeProcessDirectory`.

## Terminal purity

`buildClaudeCommand` only emits the final `claude …` invocation (with `--worktree` when starting from the repo root into a managed name, or without it when the process `cwd` is already the checkout). Any `git worktree`, `fetch`, or `rev-parse` work is done in the app layer; users should not see Agent Session Manager prepending git commands to Claude in the terminal.

## Developer map

| Area | File(s) |
|------|---------|
| Resolution + git | `Sources/AgentSessionManager/Models/Tab.swift` |
| New Pane UI | `Sources/AgentSessionManager/Views/NewPaneSheet.swift` |
| On-disk URL for a pane | `Pane.worktreePath` (managed path or `claudeDirectoryOverride`) |
| Restore existence check | `Sources/AgentSessionManager/Controllers/SessionPersistence.swift` |
| Porcelain / ref tests | `Tests/WorktreeListParserTests.swift` |

For broader app architecture, see `CLAUDE.md` in the repo root.
