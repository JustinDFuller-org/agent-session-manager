# Notifications

Agent Session Manager surfaces terminal bell events (sent by Claude Code and similar tools when they need your attention) as in-app notifications with visual indicators, optional **macOS banner notifications** (Notification Center), and a sidebar panel.

**In-app vs macOS:** The sidebar and pane/tab dots are **purely in-app** and do not require notification permission. **macOS banners** use `UNUserNotificationCenter` and require permission in **System Settings → Notifications** for Agent Session Manager. If `requestAuthorization` fails (for example `UNErrorDomain` code **1**, often meaning notifications are not allowed for the app), fix that in System Settings or by resetting the app’s notification registration — **in-app alerts still work** when a bell or hook fires; only banners are affected.

## What It Does

- **Pane indicator** — A colored dot appears in the pane header next to the process status indicator when that pane has an unread notification.
- **Tab indicator** — A colored dot appears in the tab button when any pane in that tab has a pending notification.
- **Notification sidebar** — A sidebar panel opens automatically when notifications are queued. It lists the pane name, tab name, and a formatted timestamp. Timestamps show the time (HH:mm) for today's notifications, and the date (MM/dd/yyyy) for older notifications.

- **macOS banners** — When enabled in Settings, a system notification is shown for the same events (typically when the app is not the frontmost app). Clicking the notification focuses that pane. You must allow notifications for Agent Session Manager in **System Settings → Notifications** the first time the app requests permission.

Notification dots and sidebar entries are orange for priority panes and blue for regular panes.

## Triggering a Notification

Claude Code can signal attention in these ways that Agent Session Manager recognizes:

1. **ASCII bell** — a BEL character (`\a`). To test manually:

   ```sh
   printf '\a'
   ```

2. **OSC 777** — the sequence `ESC]777;notify;title;body` terminated with BEL (0x07). Many tools use this so the BEL byte acts as an OSC string terminator; SwiftTerm delivers that through `notify` rather than `bell()`. Both paths trigger the same in-app notification and optional macOS banner.

3. **Claude `Notification` hook** (optional, Settings → Notifications → **Notification hook for attention**) — Claude Code can run settings-defined hooks when it raises a notification event (for example tool permission, or when input is idle for a long interval). Agent Session Manager merges a hook into each pane’s `--settings` file so that stdin is written to a temp file and the app raises the **same** attention path as a bell. Turn this off if you see unwanted sidebar entries. New or refreshed panes pick up changes immediately; existing panes refresh when you toggle the setting.

Attention events are surfaced even when the pane is the active (focused) pane, to keep testing and signals consistent.

**Note:** A raw BEL that appears only as the terminator of another OSC sequence does not ring the bell; that is normal terminal behavior.

## Notification Sidebar

The sidebar appears on the right side by default (configurable in Settings → Notifications). It opens automatically when there are pending notifications and closes when all notifications are cleared.

**Sidebar sections** (when priority notifications are enabled):
1. **Priority** — Notifications from panes marked as priority, at the top.
2. **Other** — Regular notifications below.

**Clearing notifications:**
- Click a notification row to navigate to that pane and clear its notification.
- Focusing a pane (clicking it or switching to its tab) automatically clears its notification.
- Use "Clear All" at the bottom of the sidebar to dismiss all at once.

## Priority Panes

When creating a new pane, a **Priority Pane** toggle is shown (if priority notifications are enabled in settings). Marking a pane as priority means:

- Its notification dot is orange instead of blue.
- Its notification appears at the top of the sidebar in the "Priority" section.

Priority is a per-pane setting and persists across app restarts.

## Configuration

Settings → Notifications exposes these controls:

| Setting | Description | Default |
|---|---|---|
| Banner Notifications | Show macOS Notification Center banners for background pane bells (permission required) | On |
| Notification hook for attention | Merge Claude Code `Notification` hook into each pane’s `--settings` (see above) | On |
| Sidebar Position | Which side the notification sidebar opens on (Left / Right) | Right |
| Priority Notifications | Enable the priority pane toggle and priority sidebar section | On |

These settings are persisted to `~/Library/Application Support/agent-session-manager/notification-settings.json` (alongside other app settings such as [debug-settings.json](debug-logging.md) under the same support directory).

## See also

- [debug-logging.md](debug-logging.md) — optional in-app debug log (process starts, git, session restore) separate from bell notifications; useful when diagnosing permission or PATH issues alongside panes.
- [panes.md](panes.md) — how panes run the shell and CLI; relates to bell events from background panes.
