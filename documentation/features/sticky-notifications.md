# Sticky Notifications

## What It Does

Agent Session Manager can post macOS banner notifications when a background pane rings the terminal bell. By default, macOS displays these as **Banners** — they appear briefly and then auto-dismiss after a few seconds.

Sticky Notifications adds two behaviors:

1. **Always-on pane cleanup**: When you activate a pane that has a pending notification, its macOS delivered notification is automatically removed from Notification Center. This works regardless of whether Sticky Notifications is enabled.

2. **App-focus cleanup** (opt-in): When Sticky Notifications is enabled in Settings, all delivered notifications are removed from Notification Center whenever Agent Session Manager becomes the active application. This ensures stale notifications don't accumulate in Notification Center after you've returned to the app.

## macOS Alerts vs. Banners

macOS has two notification styles:

- **Banners** (default): appear briefly on screen and auto-dismiss after a few seconds.
- **Alerts**: stay on screen until the user explicitly dismisses them.

The notification style is set by the user in **System Settings → Notifications** and cannot be changed programmatically by the app. To get truly persistent notifications that stay on screen until dismissed, you must switch Agent Session Manager's notification style to **Alerts** in System Settings.

## How to Configure

1. Open **Settings** (⌘,) and navigate to the **Notifications** tab.
2. In the **macOS** section, enable **Sticky Notifications**.
3. Click **Open Notification Settings** to open System Settings → Notifications directly.
4. Find **Agent Session Manager** in the list and set its notification style to **Alerts**.

With Alerts enabled, notifications will remain on screen until dismissed. With Sticky Notifications enabled, all Notification Center entries are cleared when you bring Agent Session Manager to the foreground.
