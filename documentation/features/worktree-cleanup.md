# Worktree Cleanup

When closing a pane that uses a worktree **created by Agent Session Manager** (under `.agent-session-manager/worktrees/<name>`), the app can optionally clean up the worktree by running `git worktree remove` to unregister it from Git and delete the directory.

## Managed vs. external worktrees

- **Managed worktrees** are created by Agent Session Manager under `<repo>/.agent-session-manager/worktrees/<name>` (when you open a branch or ref that does not already have a checkout on disk). Only these worktrees are eligible for cleanup.
- **External worktrees** are pre-existing checkouts that were listed by `git worktree list` when you attached to them. The app never touches these — closing the pane just closes the pane.

## How cleanup works

When you close a pane with ⌘W or the pane's close button, the app checks whether the worktree is managed. The behavior depends on the **Worktree Cleanup** setting in Settings → Panes → Cleanup:

- **Ask** (default) — A dialog appears with three options:
  - **Delete Worktree** — Removes the pane from the UI immediately, then runs `git worktree remove <path>` in the background to delete the worktree directory and unregister it from Git.
  - **Keep Worktree** — Closes the pane but leaves the worktree on disk. You can reopen it later from the New Pane sheet.
  - **Cancel** — Keeps the pane open.
- **Always Keep** — Closes the pane without asking and never deletes the worktree.
- **Always Delete** — Removes the pane from the UI immediately, then runs `git worktree remove` in the background without asking.

## Configuration

Open **Settings → Panes → Cleanup** and look for the **Worktree Cleanup** segmented control. The setting is persisted in `~/Library/Application Support/agent-session-manager/worktree-cleanup.json`.

## What cleanup actually runs

For a pane named `my-feature` in a tab rooted at `/projects/my-repo`, cleanup runs:

```
git worktree remove /projects/my-repo/.agent-session-manager/worktrees/my-feature
```

This removes the worktree entry from `.git/worktrees`, deletes the checkout directory, and prunes the administrative files. If the directory no longer exists (e.g. it was already deleted manually), the cleanup step is silently skipped.

## Session restore interaction

If you delete a worktree and later relaunch the app, the pane for that worktree will **not** be restored because the checkout directory no longer exists on disk (see session restore rules in [worktree-creation.md]({{ '/documentation/features/worktree-creation/' | relative_url }})).
