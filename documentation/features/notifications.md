# Notifications

Agent Session Manager surfaces terminal bell events (sent by Claude Code and similar tools when they need your attention) as in-app notifications with visual indicators, optional **macOS banner notifications** (Notification Center), and a sidebar panel.

**In-app vs macOS:** The sidebar and pane/tab dots are **purely in-app** and do not require notification permission. **macOS banners** use `UNUserNotificationCenter` and require permission in **System Settings → Notifications** for Agent Session Manager. If `requestAuthorization` fails (for example `UNErrorDomain` code **1**, often meaning notifications are not allowed for the app), fix that in System Settings or by resetting the app’s notification registration — **in-app alerts still work** when a bell or hook fires; only banners are affected.

**Bundle IDs (must match the app you run):** Notification permission is per bundle identifier. **Production** (`make app` / `make run`): `com.justinfuller.agent-session-manager`. **Dev** (`make run-dev`): `com.justinfuller.agent-session-manager.dev`. If you allow notifications for one variant but launch the other, banners will not work until you enable the matching entry under **System Settings → Notifications**.

**Diagnosing notification failures:** Enable **Settings → Debug** and inspect the trace stream for notification spans. Compare to an **Xcode** build (development-signed) if a **SwiftPM `make app`** build still misbehaves after `make app` (ad-hoc codesign runs automatically).

**Alerts vs authorization:** Even with `authorizationStatus == authorized`, **System Settings** can disable **alerts/banners** for the app (`alertSetting`), in which case the debug log shows `[banner] skipped alertSetting=…` and no banner is scheduled.

## What It Does

- **Pane indicator** — A crisp accent-color waiting dot replaces the soft neutral working glow in the pane header when that pane has an unread notification.
- **Tab indicator** — A crisp accent-color waiting dot appears in the tab button when any pane in that tab has a pending notification.
- **Notification sidebar** — A sidebar panel opens automatically when notifications are queued. It lists the pane name, tab name, and a formatted timestamp. Timestamps show the time (HH:mm) for today's notifications, and the date (MM/dd/yyyy) for older notifications.

- **macOS banners** — When enabled in Settings, a system notification is shown for the same events (typically when the app is not the frontmost app). Clicking the notification brings the app to front, switches to the correct tab, and gives the terminal in that pane keyboard focus. For PR merged banners, the action alert is shown after navigating to the pane. You must allow notifications for Agent Session Manager in **System Settings → Notifications** the first time the app requests permission. **By default macOS banners auto-dismiss after a few seconds.** To keep them on screen until dismissed, open **System Settings → Notifications → Agent Session Manager** and set **Alert Style** to **Persistent**. This is a user-controlled macOS setting — there is no public API to force persistent banners programmatically.

Waiting dots use the app accent color. Sidebar entries are orange for priority panes and blue for regular panes.

**Persistence:** Pending in-app notifications (dots and sidebar rows) are saved in **`sessions.json`** with the rest of the session and restored on launch, so they survive quitting the app (for example alongside **Continue on restart**). They are cleared when you open that pane, dismiss a row, clear all, or remove the tab—as before. macOS banner notifications are not replayed on restore.

## Triggering a Notification

Every harness can signal attention through the shared terminal paths:

1. **ASCII bell** — a BEL character (`\a`). To test manually:

   ```sh
   printf '\a'
   ```

2. **OSC 777** — the sequence `ESC]777;notify;title;body` terminated with BEL (0x07). Many tools use this so the BEL byte acts as an OSC string terminator; SwiftTerm delivers that through `notify` rather than `bell()`. Both paths trigger the same in-app notification and optional macOS banner.

3. **Claude attention hooks** — Agent Session Manager always merges focused hooks into each Claude pane’s `--settings` file. `PreToolUse` catches `AskUserQuestion` and `ExitPlanMode`, `PermissionRequest` catches permission dialogs, `Notification` catches `permission_prompt` and `elicitation_dialog`, and `Elicitation` catches MCP-driven input. Each writes to a temp file and raises the same attention path as a bell.

4. **Cursor `stop` hook** (optional, Settings → Notifications → Cursor → **Stop hook for attention**) — Agent Session Manager installs a user-level Cursor hook that writes stdin to a per-pane temp file keyed by `AGENT_SESSION_MANAGER_PANE_ID`. The Cursor provider watches that file and raises the same attention path when a turn stops. Existing Cursor panes do not currently refresh when this setting changes.

Attention events are surfaced even when the pane is the active (focused) pane, to keep testing and signals consistent.

**Note:** A raw BEL that appears only as the terminator of another OSC sequence does not ring the bell; that is normal terminal behavior.

## Notification Sidebar

The sidebar appears on the right side by default (configurable in Settings → Notifications). By default it is **always visible** — even when there are no pending notifications — so you have a consistent, predictable layout. Toggle **Always Show Notifications Bar** off in Settings → Notifications if you prefer the sidebar to appear only when there are queued notifications.

**Sidebar sections** (when priority notifications are enabled):
1. **Priority** — Notifications from panes marked as priority, at the top.
2. **Other** — Regular notifications below.

**Clearing notifications:**
- Click a notification row to navigate to that pane and clear its notification.
- Focusing a pane (clicking it or switching to its tab) automatically clears its notification.
- Use "Clear All" at the bottom of the sidebar to dismiss all at once.

## Priority Panes

When creating a new pane, a **Priority Pane** toggle is shown (if priority notifications are enabled in settings). Marking a pane as priority means:

- Its sidebar notification marker is orange instead of blue.
- Its notification appears at the top of the sidebar in the "Priority" section.

Priority is a per-pane setting and persists across app restarts.

## Configuration

Settings → Notifications exposes these controls:

| Setting | Description | Default |
|---|---|---|
| Banner Notifications | Show macOS Notification Center banners for background pane bells (permission required). To keep banners on screen, set Alert Style → Persistent in System Settings → Notifications. | On |
| Stop hook for attention (Cursor) | Install a Cursor `stop` hook for turn-completion attention (see above) | On |
| Sidebar Position | Which side the notification sidebar opens on (Left / Right) | Right |
| Always Show Notifications Bar | Keep the sidebar visible even when there are no pending notifications | On |
| Priority Notifications | Enable the priority pane toggle and priority sidebar section | On |

These settings are persisted to `~/Library/Application Support/agent-session-manager/notification-settings.json` (alongside other app settings such as [debug-settings.json](debug-logging.md) under the same support directory).

## Notification icon

The **banner header icon** (small app icon in the corner of a macOS notification) comes from **Launch Services** and the app bundle’s registered icon—not from `UNNotificationAttachment`. Agent Session Manager ensures Launch Services can resolve the icon as follows:

1. **Full standalone `.icns`** — `make app` / `make app-dev` compile the asset catalog with `actool --standalone-icon-behavior all`, producing a multi-resolution `AppIcon.icns` or `AppIcon-Dev.icns` in `Contents/Resources` (not a minimal placeholder).
2. **Plist keys** — `CFBundleIconFile` and `CFBundleIconName` are synced from `actool`’s partial Info.plist after compile (dev uses `AppIcon-Dev` for both).
3. **Launch Services** — After codesign, the Makefile unregisters and re-registers the bundle with `lsregister` so icon changes take effect on rebuild.
4. **Runtime registration** — On launch, `NSApp.applicationIconImage` is set from the bundle `.icns` so ad-hoc builds run from a worktree (outside `/Applications`) still expose a concrete bitmap to the system.

**Optional attachment** — The same icon may also be attached as a PNG for rich notification content; that does not control the header icon and may not appear in all notification styles on macOS.

- **Production** (`make run`): green icon via `AppIcon` / `AppIcon.icns`.
- **Dev** (`make run-dev`): yellow-tinted icon via `AppIcon-Dev` / `AppIcon-Dev.icns`.

There are no user-configurable settings for the notification icon. After changing icons, run `make clean && make run` (or `make run-dev`). If the banner still shows a generic white icon, remove Agent Session Manager from **System Settings → Notifications**, rebuild, and allow notifications again. Ad-hoc-signed local builds may still show a generic icon on some macOS versions until the app is signed with a Developer ID and notarized.

## See also

- [debug-logging.md](debug-logging.md) — optional in-app debug log (process starts, git, session restore) separate from bell notifications; useful when diagnosing permission or PATH issues alongside panes.
- [panes.md](panes.md) — how panes run the shell and CLI; relates to bell events from background panes.
- [agent-harness-feature-matrix.md](agent-harness-feature-matrix.md) — cross-harness notification coverage and known lifecycle gaps.
