---
layout: doc
title: Claude Code
description: Enable Claude Code and configure it for Agent Session Manager panes.
permalink: /documentation/user-guide/claude-code/
---

## What it is

Claude Code is one of the agent tools that can run inside an Agent Session Manager pane.

## Why you might use it

Run Claude Code in an isolated Git worktree while keeping other agent sessions visible in the same window.

## Before you start

Install Claude Code and make sure its command is available from the shell selected in **Settings → Panes → Terminal**. Enable it in **Settings → Harnesses**.

## How to use it

1. Open **New Pane** in a tab.
2. Choose **Claude Code** in **Harness**.
3. Enter a session, branch, or worktree name.
4. Review any **CLI Options** or **Environment Variables** you want to use.
5. Choose **Create Pane**.

Claude Code starts in the Git worktree prepared for the pane. Its status line can show tool-specific session information when those facts are available.

## What you should see

The pane opens a Claude Code terminal and keeps the tab available for other panes.

With **Continue on Restart** enabled, restored Claude Code panes use the available conversation-resume behavior. **Auto Session Name** can also give the session a name based on its tab and pane.

## If it does not work

- If Claude Code is missing from **Harness**, confirm that it is installed and available from the selected shell.
- If the pane exits immediately, review **Settings → Panes → Terminal → Shell** and the Claude Code options shown in **Settings → Harnesses**.
- If a restored conversation does not continue, check **Settings → Panes → Continue on Restart** and Claude Code's own session behavior.

## Related tasks

- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Tool Options]({{ '/documentation/user-guide/tool-options/' | relative_url }})
- [Continue After Restart]({{ '/documentation/user-guide/continue-after-restart/' | relative_url }})
- [Tabs and Panes]({{ '/documentation/user-guide/tabs-and-panes/' | relative_url }})
