# Worktree creation and New Pane (Claude)

This document describes how Agent Session Manager places git worktrees on disk, how the **New Pane** sheet behaves for Claude Code sessions, and how errors are surfaced. It is the reference for users and contributors working on `Tab`, `NewPaneSheet`, `Pane`, or session restore.

**See also:** [panes.md](panes.md) (pane model and sheet overview), [default-branch.md](default-branch.md) (Settings-only default branch preference and scope).

## Why this path exists

New worktrees created **by Agent Session Manager** (when you attach to a branch that is not yet checked out) are placed only under the **tab’s repo root** at:

**`.agent-session-manager/worktrees/<name>`**

That mirrors Claude Code’s convention of using **`.claude/worktrees/`** under a project: the directory makes it obvious which tool owns the trees the app creates, and `.agent-session-manager/` can later hold other app-specific data beside `worktrees/`. **No other files or subfeatures are written there in the current release**—only the per-worktree directories git links.

For those **managed** checkouts, the short `<name>` is the same identifier passed to `claude --worktree '<name>'`. On disk, the full checkout is at `<repo>/.agent-session-manager/worktrees/<name>`.

**Existing** git worktrees for the same repository may live anywhere on disk (sibling folders, `.claude/worktrees/`, etc.). If `git worktree list` shows a branch you ask for, Agent Session Manager can open that checkout: it sets the terminal’s working directory to that path and runs `claude` **without** `--worktree`, matching the usual pattern of `cd <checkout> && claude` for manually added worktrees.

## New Pane (Claude): one field, smart routing

When the CLI is **Claude Code**, the sheet shows a **single** text field. You can type any of the following (the app does not use a separate toggle anymore):

- A **short session name** (letters, digits, `.`, `_`, `-` only)—used when that string is **not** an existing Git ref in the repository. The app starts Claude from the tab directory with `claude --worktree '<name>'` and does **not** run `git worktree add` for that path. Claude owns how that worktree is materialized.
- A **branch or ref** such as `main`, `origin/feature`, or `refs/heads/…`. Slashes or a `refs/` prefix skip the “simple name” character rules in the UI so these inputs stay valid.
- A **managed worktree folder name**—the last segment of `<repo>/.agent-session-manager/worktrees/<name>` when that path already exists as a linked git worktree.

On **Open**, the app classifies the trimmed string (see below) and then either asks for confirmation, runs in-app Git setup, or hands off to Claude’s `--worktree`.

When the CLI is **Codex**, only a **Session name** field is shown; git worktree resolution does not apply.

### How input is classified

`Tab.classifyClaudePaneIntent(userRef:)` returns a `ClaudePaneIntent` after a read-only pass (no `fetch`, no `worktree add`):

1. **`.reuse`** — An existing checkout already matches the input (same early logic as `peekExistingResolvedWorktree`: managed path on disk, a hit from `git worktree list --porcelain`, or the derived managed path for a ref that already exists). The sheet shows a **confirmation dialog**; if the user continues, `resolveOrAttachWorktree` runs and the pane opens with the same semantics as today (managed → `claude --worktree` from repo root; external listing → `cwd` at that path, no `--worktree`).
2. **`.resolveViaApp`** — The input looks like a ref (e.g. contains `/` or `refs/`) **or** `git rev-parse` resolves it to a commit, but there is no reuse match yet. The app runs `Tab.resolveOrAttachWorktree` (fetch if needed, then `git worktree add` under `.agent-session-manager/worktrees/<derived>` when creating a new tree). No extra confirmation step beyond errors in the sheet.
3. **`.claudeWorktreeFlag(name:)`** — The input is a valid simple name, no checkout matched, and Git does not treat it as a ref. The app adds a pane with `claude --worktree '<name>'` from the tab directory (same as the historical “default” path).

**Edge case:** A branch that exists **only** on the remote and is not yet available to `rev-parse` locally may be classified as `.claudeWorktreeFlag` until you fetch or use a ref Git can resolve; this is called out in code on `classifyClaudePaneIntent`.

Duplicate panes in the same tab are still blocked by **checkout directory** (and by simple name when that applies to the Claude-flag path).

## Resolution order (`resolveOrAttachWorktree`)

Implementation lives in `Tab.resolveOrAttachWorktree(userRef:)`, which returns a `ResolvedWorktree` (`paneTitle`, optional process-directory override, `checkoutURL`). The attach/create path begins with **`peekExistingResolvedWorktree`** (shared with classification). At a high level:

1. **Trim** the input. If it is a **valid worktree name** and `<repo>/.agent-session-manager/worktrees/<input>` already exists and looks like a **linked git worktree** (a `.git` *file* with `gitdir:`), that name is used as a managed resolution.

2. **`git worktree list --porcelain`** is parsed. A listing whose **worktree path’s last segment** equals your input is chosen first (so `…/worktree-meter-chore-claude-review` wins over another checkout whose *branch name* is also `worktree-meter-chore-claude-review`).
3. Otherwise the first listing whose **branch** matches the input (short name, `refs/heads/…`, `refs/remotes/…`, `origin/…`-style):
   - If that entry’s path is **under** `<repo>/.agent-session-manager/worktrees/`, the **final path segment** is the managed short name (`claude --worktree` from the repo root).
   - Otherwise the app **reuses** that checkout: process `cwd` is that path, the Claude command **omits** `--worktree`. Paths reported by `git worktree list` are trusted (including the main repo checkout, where `.git` is a directory).

4. Otherwise the app picks a **derived folder name** from the ref (last path segment, sanitized), verifies the ref with `git rev-parse`, runs **`git fetch origin <ref>`** if needed, creates **`.agent-session-manager`** if needed, and runs **`git worktree add .agent-session-manager/worktrees/<n> <ref>`** (only this path is used for **new** trees). If `worktree add` fails because the branch is already checked out, the list is consulted again so a managed or external checkout can be returned.

## Session restore

`SessionPersistence` restores Claude panes when the checkout still exists:

- **`claudeProcessDirectory` set** in `sessions.json`: that absolute path must still exist.
- Otherwise the **managed** path `<tab-dir>/.agent-session-manager/worktrees/<name>`, or legacy `<tab-dir>/.tree/<name>`.

So old sessions can still restore if only the legacy path exists; reused external checkouts persist via `claudeProcessDirectory`.

## Terminal purity

`buildClaudeCommand` only emits the final `claude …` invocation (with `--worktree` when starting from the repo root into a managed name, or without it when the process `cwd` is already the checkout). Any `git worktree`, `fetch`, or `rev-parse` work is done in the app layer; users should not see Agent Session Manager prepending git commands to Claude in the terminal.

## Base ref for new worktrees

When Agent Session Manager creates a new worktree from the default branch (the path under step 4 in *Resolution order* above), you can control what commit that worktree starts from via **Settings → Panes → New Pane** (the **Starting Point** control):

| Option | Starting point | When to use |
|--------|---------------|-------------|
| **Fresh** (default) | `origin/<default-branch>` — fetched fresh from the remote | You want a clean tree that matches the remote, regardless of local `main` state |
| **HEAD** | Local `HEAD` — whatever is currently checked out in the tab's directory | You want the worktree to include unpushed commits or feature-branch work |

This setting maps directly to Claude Code's `worktree.baseRef` concept (`fresh` vs `head`). The value persists across launches and is stored under `Application Support/agent-session-manager/worktree-base-ref.json`.

**Note:** Base ref only applies when creating a *new* worktree from the default branch. Attaching to an existing ref (step 3 in the resolution order) always checks out that specific ref regardless of this setting.

## Developer map

| Area | File(s) |
|------|---------|
| Resolution + git | `Sources/AgentSessionManager/Models/Tab.swift` (`resolveOrAttachWorktree`, `classifyClaudePaneIntent`, `peekExistingResolvedWorktree`, `ClaudePaneIntent`) |
| New Pane UI | `Sources/AgentSessionManager/Views/NewPaneSheet.swift` |
| On-disk URL for a pane | `Pane.worktreePath` (managed path or `claudeDirectoryOverride`) |
| Restore existence check | `Sources/AgentSessionManager/Controllers/SessionPersistence.swift` |
| Porcelain / ref tests | `Tests/WorktreeListParserTests.swift` |
| Intent / routing tests | `Tests/ClaudePaneIntentTests.swift` |
| New Pane Git routing (UI) | `UITests/NewPaneWorktreeRoutingTests.swift`, `UITests/GitUITestWorkspace.swift` (clean repo + branch helpers), `UITests/BaseTestCase.swift` |

For broader app architecture, see `CLAUDE.md` in the repo root.
