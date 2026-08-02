---
layout: doc
title: Codex
description: Enable Codex and configure it for Agent Session Manager panes.
diataxis_type: how-to
permalink: /documentation/user-guide/codex/
---

## What it is

Codex is one of the agent tools that can run inside an Agent Session Manager pane.

## Why you might use it

Run Codex in an isolated Git worktree while organizing several agent tasks in tabs and panes.

## Before you start

Install Codex and make sure its command is available from the shell selected in **Settings → Panes → Terminal**. Enable it in **Settings → Harnesses**.

## How to use it

1. Open **New Pane** in a tab.
2. Choose **Codex** in **Harness**.
3. Enter a session, branch, or worktree name.
4. Review the Codex **CLI Options** shown in the sheet.
5. Choose **Create Pane**.

Codex starts in the Git worktree prepared for the pane. The status line can show app-owned facts and supported Codex session information.

## What you should see

The pane opens a Codex terminal and remains part of the tab's saved layout.

After a restart, Codex panes reopen in their saved working copies. **Continue on Restart** does not add a separate continuation option to Codex.

## If it does not work

- If Codex is missing from **Harness**, confirm that it is installed and available from the selected shell.
- If the pane exits immediately, review **Settings → Panes → Terminal → Shell** and the Codex options shown in **Settings → Harnesses**.
- If the Git worktree cannot be prepared, see [Project Isolation]({{ '/documentation/user-guide/project-isolation/' | relative_url }}).

## Related tasks

- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Tool Options]({{ '/documentation/user-guide/tool-options/' | relative_url }})
- [Status Line]({{ '/documentation/user-guide/status-line/' | relative_url }})
- [Project Isolation]({{ '/documentation/user-guide/project-isolation/' | relative_url }})
