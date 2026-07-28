---
layout: doc
title: Agent Control
description: Let supported agent tools inspect and manage the surrounding Agent Session Manager workspace.
permalink: /documentation/user-guide/agent-control/
---

## What it is

Agent Control gives a supported agent tool access to the Agent Session Manager workspace around its pane. Depending on the selected scope, the agent can inspect tabs, panes, profiles, status information, notifications, and diagnostics, and perform supported session-management actions.

Agent Session Manager starts an app-owned local Model Context Protocol (MCP) server and prepares the selected harness to connect to it when the pane launches. The connection is configured for that pane and scope; it is not a shell command that users need to type.

## Why you might use it

Use Agent Control when you want an agent to coordinate its session with the rest of the workspace. For example, an agent can work with other panes in its tab, update shared configuration, or help investigate a problem without requiring you to perform every workspace action manually.

Agent Control is available for panes using Claude Code, Cursor, Codex, or OpenCode.

## How it connects to your agent tool

Agent Session Manager prepares the MCP connection before it starts the final harness command:

- **Claude Code** receives an MCP configuration through its supported `--mcp-config` option.
- **Cursor** receives a private plugin directory through `--plugin-dir`. The plugin starts Agent Session Manager's bundled stdio bridge, which securely forwards to the app-owned local server using runtime-only connection details. It does not modify project or user Cursor files. If the bridge or control service is temporarily unavailable, the pane opens normally without Agent Control instead of showing a setup error.
- **Codex** receives the MCP server URL and runtime credential through supported `-c` settings.
- **OpenCode** receives the connection through its inline configuration. Existing OpenCode MCP entries and unrelated settings are preserved.

Each injected pane receives a runtime-only credential for its connection. The credential is not persisted, logged, or printed in the terminal, and it is revoked when the pane or tab is torn down.

## Before you start

Enable a supported tool in [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }}) and make sure it is available from the shell selected in **Settings → Panes → Terminal**.

## How to use it

1. Open **Settings** and select **Panes**.
2. Under **Agent Control**, choose an **Injection Policy**:
   - **Always** enables control for every new or restarted pane.
   - **Never** disables control for every new or restarted pane.
   - **Ask (on by default)** or **Ask (off by default)** shows a per-pane choice when you create a pane.
3. Choose a **Scope**:
   - **Pane** lets the agent access only its own pane.
   - **Tab** lets the agent access every pane in its tab.
   - **Global** lets the agent access the entire app.
4. Open **New Pane** and select Claude Code, Cursor, Codex, or OpenCode in **Harness**.
5. If you chose an ask policy, enable or disable **Agent Session Manager control** in the **Agent Control** section.
6. Choose **Create Pane**.

**Global** is the default scope. Some app-wide configuration and diagnostic actions require Global scope.

Changing the policy or scope affects future launches, restores, and restarts. Restart an existing pane after changing these settings.

## What the agent can access and control

The available surface depends on the selected scope. Scope is enforced for every read and change, so an agent cannot use a control that reaches outside its scope.

| Area | Available operations |
| --- | --- |
| Workspace | Read the workspace, tabs, panes, worktrees, setup state, and pane status available in scope |
| Tabs and panes | Create, inspect, focus, restart, delete, and reorder tabs and panes |
| Profiles and harnesses | Read visible profiles; create, edit, delete, and reorder profiles; enable harnesses and configure CLI options when Global scope is available |
| Status line | Read status-line configuration and pane data; update global or profile-specific status-line settings with Global scope |
| Notifications | Read visible notifications, acknowledge them, and navigate to their pane |
| Diagnostics | Read bounded diagnostic summaries, traces, invariant occurrences, and app-owned logs available in scope; change Debug Mode with Global scope |

Names are display values. Agent Control uses stable object identities so actions continue to target the intended tab, pane, profile, or notification when names are duplicated.

## What you should see

With an ask policy, **New Pane** shows the **Agent Session Manager control** checkbox and the current scope. With **Always** or **Never**, the sheet shows whether control will be enabled or disabled instead of showing a checkbox.

After the pane starts, the supported agent can use Agent Control within the selected scope. The pane continues to run the selected agent tool in its prepared Git worktree.

## If it does not work

- If the control checkbox is not shown, check **Settings → Panes → Injection Policy**. **Always** and **Never** show a status message instead of a checkbox.
- Cursor may still ask for normal MCP approval. Approve the Agent Session Manager server through Cursor, or enable Cursor's own MCP approval option if that is appropriate for your workflow.
- If a policy or scope change has no effect on a running pane, restart the pane.
- If an action is unavailable, choose **Global** scope when the action needs access beyond the current pane or tab.

## Related tasks

- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Tabs and Panes]({{ '/documentation/user-guide/tabs-and-panes/' | relative_url }})
- [Profiles]({{ '/documentation/user-guide/profiles/' | relative_url }})
- [Troubleshooting]({{ '/documentation/user-guide/troubleshooting/' | relative_url }})
