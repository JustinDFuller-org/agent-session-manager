---
layout: doc
title: Cursor
description: Enable Cursor and configure it for Agent Session Manager panes.
permalink: /documentation/user-guide/cursor/
---

## What it is

Cursor is one of the agent tools that can run inside an Agent Session Manager pane.

## Why you might use it

Run Cursor in an isolated Git worktree while keeping related agent tasks together in a tab.

## Before you start

Install the Cursor agent command and make sure it is available from the shell selected in **Settings → Panes → Terminal**. Enable it in **Settings → Harnesses**.

## How to use it

1. Open **New Pane** in a tab.
2. Choose **Cursor** in **Harness**.
3. Enter a session, branch, or worktree name.
4. Review the Cursor **CLI Options** shown in the sheet.
5. Choose **Create Pane**.

Cursor starts in the Git worktree prepared for the pane. You can enable its attention hook from **Settings → Notifications** if you want a notification when a turn completes.

## What you should see

The pane opens a Cursor terminal and remains part of the tab's saved layout.

After a restart, Cursor panes reopen in their saved working copies. With **Continue on Restart** enabled, the app passes Cursor `--continue` so the latest chat reopens automatically, unless the pane has an explicit `--resume` option.

## If it does not work

- If Cursor is missing from **Harness**, confirm that it is installed and available from the selected shell.
- If the pane exits immediately, review **Settings → Panes → Terminal → Shell** and the Cursor options shown in **Settings → Harnesses**.
- If completion attention is missing, check **Stop hook for attention** in **Settings → Notifications** and reopen the pane.

## Related tasks

- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Tool Options]({{ '/documentation/user-guide/tool-options/' | relative_url }})
- [Notifications]({{ '/documentation/user-guide/notifications/' | relative_url }})
- [Project Isolation]({{ '/documentation/user-guide/project-isolation/' | relative_url }})
