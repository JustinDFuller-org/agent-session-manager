---
layout: doc
title: Agent Control
description: Let supported agent tools inspect and manage the surrounding Agent Session Manager workspace.
permalink: /documentation/user-guide/agent-control/
---

## What it is

Agent Control gives a supported agent tool access to the Agent Session Manager workspace around its pane. Depending on the selected scope, the agent can inspect tabs, panes, profiles, status information, notifications, and diagnostics, and perform supported session-management actions.

## Why you might use it

Use Agent Control when you want an agent to coordinate its session with the rest of the workspace. For example, an agent can work with other panes in its tab, update shared configuration, or help investigate a problem without requiring you to perform every workspace action manually.

Agent Control is available for panes using Claude Code, Codex, or OpenCode. Cursor does not currently support Agent Control injection.

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
4. Open **New Pane** and select Claude Code, Codex, or OpenCode in **Harness**.
5. If you chose an ask policy, enable or disable **Agent Session Manager control** in the **Agent Control** section.
6. Choose **Create Pane**.

**Global** is the default scope. Some app-wide configuration and diagnostic actions require Global scope.

Changing the policy or scope affects future launches, restores, and restarts. Restart an existing pane after changing these settings.

## What you should see

With an ask policy, **New Pane** shows the **Agent Session Manager control** checkbox and the current scope. With **Always** or **Never**, the sheet shows whether control will be enabled or disabled instead of showing a checkbox.

After the pane starts, the supported agent can use Agent Control within the selected scope. The pane continues to run the selected agent tool in its prepared working copy.

## If it does not work

- If the control checkbox is not shown, check **Settings → Panes → Injection Policy**. **Always** and **Never** show a status message instead of a checkbox.
- If a pane uses Cursor, disable Agent Control for that pane or choose Claude Code, Codex, or OpenCode. Cursor does not support the required per-pane setup.
- If a policy or scope change has no effect on a running pane, restart the pane.
- If an action is unavailable, choose **Global** scope when the action needs access beyond the current pane or tab.

## Related tasks

- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Tabs and Panes]({{ '/documentation/user-guide/tabs-and-panes/' | relative_url }})
- [Profiles]({{ '/documentation/user-guide/profiles/' | relative_url }})
- [Troubleshooting]({{ '/documentation/user-guide/troubleshooting/' | relative_url }})
