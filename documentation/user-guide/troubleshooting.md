---
layout: doc
title: Troubleshooting
description: Recover when an update, permission, tool, pane, or checkout does not work as expected.
permalink: /documentation/user-guide/troubleshooting/
---

## What it is

Use this guide when Agent Session Manager cannot update, find an agent tool, start a pane, access a project, or open the working copy you selected.

## Updates

### No update appears

1. Open **Settings → About**.
2. Choose **Check for Updates**.
3. If no update is found, confirm that the Mac is connected to the internet and try again later.

The update path depends on how Agent Session Manager was installed. A release DMG can download and install a newer release. A source-built copy reports newer changes from its source checkout and does not install them automatically.

### An update is available for a release DMG

Choose **Install Update** in **Settings → About**, or select **Update available** in the tab bar. Follow the macOS update prompts and allow the app to relaunch when the installation finishes.

### An update is available for a source-built copy

Open **Settings → About** and follow the displayed source-update instruction. The app must be rebuilt from the updated checkout before the new version is available.

## macOS permission prompts

The first pane for a project may cause macOS to ask whether Agent Session Manager can access files in protected locations or data from other apps. Allow access when you want the agent to work with that project. macOS remembers the decision for the app.

If access still fails:

1. Open **System Settings → Privacy & Security**.
2. Review Agent Session Manager under **Files and Folders**.
3. If the project still cannot be opened, review **Full Disk Access** and relaunch the app after changing the permission.

Do not grant access to a project or folder that you do not want the agent tool to use.

## A tool is missing

If a tool does not appear in **New Pane → Harness**:

1. Confirm that the tool is installed.
2. Open **Settings → Harnesses** and enable the tool.
3. Open **Settings → Panes** and review **Shell**. Leave it on **Auto-detect** unless the tool is installed through a shell-specific package manager or version manager.
4. Close and reopen **New Pane**.

If the tool is installed but still cannot be found, choose **Other…** under **Shell** and enter the full path to the shell executable, then try again. A plain shell opened with **Open Shell Here** does not require an active agent tool.

## A pane will not start

### The pane says “Setting up workspace…”

Wait for the workspace setup to finish. The app may need to inspect Git worktrees, fetch a branch, or create a working copy before the terminal starts.

### The pane shows an error

Read the message in the pane, correct the named problem, and create the pane again. Choose **Remove Pane** to dismiss the failed pane.

Common causes include a missing branch or ref, a network failure while fetching, a path that is not a Git worktree, or an agent tool that is not available in the selected shell.

### The process exits immediately

When the process-exit controls appear, choose **Restart** to try the same pane again, **Open Shell** to inspect the working copy, or **Close** to remove the pane. If restarting produces the same result, check the selected tool, shell, and tool-specific options.

## A checkout conflicts with another task

### The worktree is already open

Agent Session Manager does not open the same checkout in two panes in the same tab. Close the pane that already uses it, or use that pane instead of creating a duplicate.

### The branch or ref cannot be found

Check the spelling and enter the branch or ref exactly. Use a full ref such as `origin/feature` when the short name is ambiguous. If you want a new task working copy from a simple name, open **Settings → Panes → New Pane**, enable **Default Branch**, and confirm the configured branch and **Starting Point**.

### A path exists but is not a worktree

Choose a valid branch, ref, or existing Git worktree instead. New task names may contain only letters, digits, dots, underscores, and dashes.

### An existing worktree is outside the app-managed location

When **Manage existing worktree** appears, choose **Manage** if Agent Session Manager should be able to clean up that worktree later, or **Don't Manage** if the checkout should remain under your control. Choose **Cancel** to stop creating the pane.

## Related tasks

- [Install and First Launch]({{ '/documentation/user-guide/install/' | relative_url }})
- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Tabs and Panes]({{ '/documentation/user-guide/tabs-and-panes/' | relative_url }})
- [Project Isolation]({{ '/documentation/user-guide/project-isolation/' | relative_url }})
- [Continue After Restart]({{ '/documentation/user-guide/continue-after-restart/' | relative_url }})
- [Worktree Cleanup]({{ '/documentation/user-guide/worktree-cleanup/' | relative_url }})
