---
layout: doc
title: Worktree Cleanup
description: Choose what happens to a managed working copy when you close a pane.
permalink: /documentation/user-guide/worktree-cleanup/
---

## What it is

Worktree cleanup controls whether Agent Session Manager removes a task working copy when you close its pane. It applies to working copies managed by the app, not to every checkout on your Mac.

## Why you might use it

Delete finished task working copies to keep a repository tidy, or keep them when you may want to reopen the task later.

## Before you start

Understand whether the pane uses a working copy created or managed by Agent Session Manager. An existing external checkout is not removed just because its pane is closed.

## How to use it

### Choose cleanup behavior

1. Open **Settings**.
2. Select **Panes**.
3. In the **Cleanup** section, find **Worktree Cleanup**.
4. Choose one of the available behaviors:
   - **Ask** shows the choices each time.
   - **Always Keep** closes the pane and keeps the working copy.
   - **Always Delete** closes the pane and removes the managed working copy.

### Decide when prompted

When **Ask** is selected and you close a managed pane:

- Choose **Delete Worktree** to close the pane and remove the managed working copy.
- Choose **Keep Worktree** to close the pane while leaving the working copy available to reopen.
- Choose **Cancel** to leave the pane open.

## What you should see

Closing an externally managed checkout simply closes the pane. Closing a managed working copy follows the selected cleanup behavior.

## If it does not work

- If no cleanup dialog appears, the pane may use an external checkout or cleanup may be set to **Always Keep** or **Always Delete**.
- If a deleted task does not return after relaunch, create a new pane from its branch or ref.
- If you need the files later, choose **Keep Worktree** before closing the pane.

## Related tasks

- [Project Isolation](project-isolation/)
- [Continue After Restart](continue-after-restart/)
- [Tabs and Panes](tabs-and-panes/)
