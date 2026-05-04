# Worktree creation and New Pane (Claude)

This document describes how Agent Session Manager places git worktrees on disk, how the **New Pane** sheet behaves for Claude Code sessions, and how errors are surfaced. It is the reference for users and contributors working on `Tab`, `NewPaneSheet`, `Pane`, or session restore.

## Why this path exists

ASM keeps every worktree it creates or manages under the **tab’s repo root** at:

**`.agent-session-manager/worktrees/<name>`**

That mirrors Claude Code’s convention of using **`.claude/worktrees/`** under a project: the directory makes it obvious which tool owns the trees, and `.agent-session-manager/` can later hold other app-specific data beside `worktrees/`. **No other files or subfeatures are written there in the current release**—only the per-worktree directories git links.

The short `<name>` is the same identifier passed to `claude --worktree '<name>'`. On disk, the full checkout is at `<repo>/.agent-session-manager/worktrees/<name>`.

## New Pane: two modes (Claude only)

When the CLI is **Claude Code**:

1. **Default — “Existing branch or worktree” is off**  
   You enter a **Session name** (letters, digits, `.`, `_`, `-` only). The app does **not** run `git worktree add` in this path; it starts Claude with `claude --worktree '<name>'` from the tab directory. Claude may create or use its own layout; the sheet’s path hint shows where ASM’s managed worktrees live for consistency.

2. **“Existing branch or worktree” is on**  
   The Session name field is **hidden**. You enter a single **branch, ref, or worktree name** (`main`, `origin/feature`, a folder name that matches `.agent-session-manager/worktrees/<name>`, etc.). The app resolves that input (see below), then opens a pane with the **resolved** short name. All git setup runs in Swift (`Foundation.Process`); failures appear in the sheet, never as extra shell noise in the terminal.

When the CLI is **Codex**, only the Session name field is shown; worktree resolution does not apply.

## Resolution order (toggle on)

Implementation lives in `Tab.resolveOrAttachWorktree(userRef:)`. At a high level:

1. **Trim** the input. If it is a **valid worktree name** and `<repo>/.agent-session-manager/worktrees/<input>` already exists and looks like a **linked git worktree** (a `.git` *file* with `gitdir:`), that name is returned.

2. **`git worktree list --porcelain`** is parsed. If some entry’s **branch** matches the input (short name, `refs/heads/…`, `refs/remotes/…`, `origin/…`-style), and that entry’s path lies **under** `<repo>/.agent-session-manager/worktrees/`, the **final path segment** is returned as the pane name.

3. If the branch is checked out in a worktree **outside** that directory, the app returns a **clear error** instead of guessing: ASM only supports `claude --worktree '<shortName>'` for trees it manages under `.agent-session-manager/worktrees/`.

4. Otherwise the app picks a **derived folder name** from the ref (last path segment, sanitized), verifies the ref with `git rev-parse`, runs **`git fetch origin <ref>`** if needed, creates **`.agent-session-manager`** if needed, and runs **`git worktree add .agent-session-manager/worktrees/<n> <ref>`**. If `worktree add` fails because the branch is already bound elsewhere, the list is consulted again to return a managed name or the same outside-directory error.

The resolved string must be a valid worktree name and must not duplicate an **already open** pane for that tab.

## Session restore

`SessionPersistence` restores Claude panes only if a directory still exists on disk for that pane name. It checks, in order:

- `<tab-dir>/.agent-session-manager/worktrees/<name>` (current layout)  
- `<tab-dir>/.tree/<name>` (**legacy** layout from older builds)

So old sessions can still restore if only the legacy path exists; new work happens under `.agent-session-manager/worktrees/`.

## Terminal purity

`buildClaudeCommand` only emits the final `claude …` invocation. Any `git worktree`, `fetch`, or `rev-parse` work is done in the app layer; users should not see ASM prepending git commands to Claude in the terminal.

## Developer map

| Area | File(s) |
|------|---------|
| Resolution + git | `Sources/AgentSessionManager/Models/Tab.swift` |
| New Pane UI | `Sources/AgentSessionManager/Views/NewPaneSheet.swift` |
| On-disk URL for a pane | `Pane.worktreePath` → `Tab.worktreeDirectoryURL` |
| Restore existence check | `Sources/AgentSessionManager/Controllers/SessionPersistence.swift` |
| Porcelain / ref tests | `Tests/WorktreeListParserTests.swift` |

For broader app architecture, see `CLAUDE.md` in the repo root.
