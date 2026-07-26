# Worktree Creation and New Pane

This document describes the shared worktree path used when creating Claude Code, Cursor, or Codex panes. See [agent-harness-feature-matrix.md]({{ '/documentation/features/agent-harness-feature-matrix/' | relative_url }}) for the full cross-harness audit.

## Shared New Pane Flow

The New Pane sheet has one **Session, branch, or worktree** field for every harness. On **Create Pane**, Agent Session Manager:

1. Adds a loading pane.
2. Calls `Tab.resolveOrAttachWorktree(userRef:defaultBranch:baseRef:)`.
3. Reuses an existing checkout or creates a linked worktree under `.agent-session-manager/worktrees/<name>`.
4. Launches the selected harness inside the resolved checkout directory.

There is no Claude-only classification path and the app does not delegate worktree creation to a harness CLI.

## Resolution Order

`Tab.resolveOrAttachWorktree` resolves the trimmed input in this order:

1. Reuse an existing linked worktree at `<repo>/.agent-session-manager/worktrees/<input>`.
2. Parse `git worktree list --porcelain`. Prefer a matching directory name, then a matching branch or ref.
3. Fetch `origin <input>` and attach a matching local or remote ref by running `git worktree add .agent-session-manager/worktrees/<name> <ref>`.
4. If no matching ref exists and the default-branch setting is enabled, create a new branch and linked worktree from the configured starting point.
5. If the default-branch setting is disabled, report that the ref was not found.

New worktrees created by Agent Session Manager live only under:

`<repo>/.agent-session-manager/worktrees/<name>`

Existing worktrees listed by Git may live anywhere. The New Pane flow can reuse them and optionally take over management so cleanup is available later.

## Default Branch and Starting Point

Settings → Panes → New Pane controls fallback creation for a plain name that does not already resolve:

| Setting | Behavior |
|---|---|
| **Default Branch** enabled | Create a new branch and linked worktree from the configured branch |
| **Default Branch** disabled | Reject an input that does not resolve to an existing ref or checkout |
| **Fresh** starting point | Fetch and branch from `origin/<default-branch>` |
| **HEAD** starting point | Branch from local `HEAD` |

See [default-branch.md]({{ '/documentation/features/default-branch/' | relative_url }}).

## Cleanup

Cleanup depends on `Pane.worktreeIsManaged`, not the selected harness. New app-created worktrees are managed. External worktrees can be managed when the user chooses takeover. See [worktree-cleanup.md]({{ '/documentation/features/worktree-cleanup/' | relative_url }}).

## Session Restore

`sessions.json` stores each pane's resolved `worktreeDirectory`. Restore restarts any harness when that directory still exists. Legacy Claude entries without a stored directory still fall back to `<tab-dir>/.agent-session-manager/worktrees/<name>` or `<tab-dir>/.tree/<name>`.

The persisted `claudeProcessDirectory` key is decode-only compatibility for older sessions; new sessions write `worktreeDirectory`.

## Terminal Purity

Worktree setup runs in Swift through `Foundation.Process` before the terminal process starts. Harness launch commands contain only the final tool invocation (`claude`, `agent`, or `codex`) and configured arguments.

## Developer Map

| Area | File |
|---|---|
| Shared resolution and Git commands | `Sources/AgentSessionManager/Models/Tab.swift` |
| Loading and shared New Pane flow | `Sources/AgentSessionManager/Views/NewPaneSheet.swift` |
| Persisted checkout restore | `Sources/AgentSessionManager/Controllers/SessionPersistence.swift` |
| Cleanup | `Sources/AgentSessionManager/Models/Tab.swift` |
