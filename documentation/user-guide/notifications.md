---
layout: doc
title: Notifications
description: Notice when an agent pane needs attention and choose how alerts appear.
permalink: /documentation/user-guide/notifications/
---

## What it is

Agent Session Manager can show attention in the pane and tab indicators, the in-app notifications sidebar, and optional macOS banners. Notifications can come from terminal alerts, supported agent-tool events, or tracked pull-request events.

## Why you might use it

Notifications let you keep working in one pane while another pane waits for input or finishes a turn.

## Before you start

In-app indicators and the notifications sidebar do not require macOS permission. macOS banners require permission in **System Settings → Notifications** for Agent Session Manager.

## How to use it

### Read and clear notifications

- A waiting dot on a pane or tab means that pane needs attention.
- Open a notification row to switch to its tab and pane.
- Focusing a pane clears its notification.
- Use **Clear All** in the sidebar to dismiss all current rows.

The sidebar can group priority notifications above other notifications. Priority is selected per pane when **Priority Notifications** is enabled.

### Configure notifications

1. Open **Settings → Notifications**.
2. Enable **Banner Notifications** if you want macOS alerts.
3. Configure tool-specific completion alerts such as **Notify when Claude stops**, **Stop hook for attention**, or **Notify when OpenCode stops**.
4. Choose the **Sidebar Position** and whether to enable **Always Show Notifications Bar**.
5. Enable **Priority Notifications** if you want to mark important panes.

To keep macOS banners visible until dismissed, choose **Open Notification Settings** and set Agent Session Manager’s Alert Style to **Persistent**.

## What you should see

The sidebar shows the pane and tab associated with each pending notification. Clicking a macOS banner brings Agent Session Manager forward and focuses the related pane.

![Agent Session Manager Notifications settings]({{ '/assets/img/docs/settings-notifications.png' | relative_url }})

_Notifications settings control banners, tool completion alerts, and sidebar behavior._

## If it does not work

- If in-app notifications appear but macOS banners do not, allow notifications for the correct Agent Session Manager app in **System Settings → Notifications**.
- If the sidebar is hidden, enable **Always Show Notifications Bar** or wait for a pending notification.
- If a tool completion alert is missing, check its tool-specific setting in **Settings → Notifications** and reopen the pane after changing hook-related settings.

## Related tasks

- [Focus Pane]({{ '/documentation/user-guide/focus-pane/' | relative_url }})
- [Tabs and Panes]({{ '/documentation/user-guide/tabs-and-panes/' | relative_url }})
- [Status Line]({{ '/documentation/user-guide/status-line/' | relative_url }})
