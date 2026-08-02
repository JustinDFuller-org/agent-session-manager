---
layout: doc
title: OpenCode
description: Enable OpenCode and configure it for Agent Session Manager panes.
diataxis_type: how-to
permalink: /documentation/user-guide/opencode/
---

## What it is

OpenCode is one of the agent tools that can run inside an Agent Session Manager pane.

## Why you might use it

Run OpenCode in an isolated Git worktree and monitor its session alongside other agent panes.

## Before you start

Install OpenCode and make sure its command is available from the shell selected in **Settings → Panes → Terminal**. Enable it in **Settings → Harnesses**.

## How to use it

1. Open **New Pane** in a tab.
2. Choose **OpenCode** in **Harness**.
3. Enter a session, branch, or worktree name.
4. Review any OpenCode **CLI Options** or **Environment Variables** you want to use.
5. Choose **Create Pane**.

OpenCode starts in the Git worktree prepared for the pane. Its status line can show supported session information while the pane is running.

## What you should see

The pane opens an OpenCode terminal and remains part of the tab's saved layout.

With **Continue on Restart** enabled, restored OpenCode panes use their available session-resume behavior.

## If it does not work

- If OpenCode is missing from **Harness**, confirm that it is installed and available from the selected shell.
- If the pane exits immediately, review **Settings → Panes → Terminal → Shell** and the OpenCode options shown in **Settings → Harnesses**.
- If a restored session does not continue, check **Settings → Panes → Continue on Restart** and OpenCode's own session behavior.

## Related tasks

- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Tool Options]({{ '/documentation/user-guide/tool-options/' | relative_url }})
- [Continue After Restart]({{ '/documentation/user-guide/continue-after-restart/' | relative_url }})
- [Status Line]({{ '/documentation/user-guide/status-line/' | relative_url }})
