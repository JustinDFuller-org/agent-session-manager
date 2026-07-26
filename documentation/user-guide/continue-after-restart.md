---
layout: doc
title: Continue After Restart
description: Reopen saved tabs and panes after Agent Session Manager restarts.
permalink: /documentation/user-guide/continue-after-restart/
---

## What it is

Agent Session Manager saves open tabs and agent panes so it can restore them after the app is relaunched. A pane is restored only when its working copy still exists on disk.

## Why you might use it

Session restoration lets you close the app or restart your Mac without rebuilding your project layout manually. The **Continue on Restart** setting can also resume supported agent conversations.

## Before you start

Keep the working copies used by your panes on disk. If you delete a working copy, the related pane cannot be restored.

## How to use it

1. Open **Settings**.
2. Select **Panes**.
3. In the **Cleanup** section, enable or disable **Continue on Restart**.
4. Quit and reopen Agent Session Manager.

The app restores tabs and panes whose working copies still exist. With **Continue on Restart** enabled, Claude Code and OpenCode use their available conversation-resume behavior. Codex and Cursor panes reopen in their working copies without an added continuation option.

## What you should see

The saved tabs reappear when their project directories can be restored, with each restorable pane starting in its saved working copy. Panes whose project directory or working copy is missing are left out of the restored session.

## If it does not work

- If a tab or pane is missing, confirm that its project directory and working copy still exist.
- If the project path contains spaces and the tab does not return, update to a build containing the current session-restore fix or recreate the tab.
- If the pane reopens but the conversation does not resume, check **Settings → Panes → Continue on Restart** and the selected tool's own session behavior.
- If you intentionally deleted the working copy, create a new pane from the relevant branch or worktree.

## Related tasks

- [Project Isolation]({{ '/documentation/user-guide/project-isolation/' | relative_url }})
- [Worktree Cleanup]({{ '/documentation/user-guide/worktree-cleanup/' | relative_url }})
- [Tabs and Panes]({{ '/documentation/user-guide/tabs-and-panes/' | relative_url }})
