# Debug Logging

## What it does

Debug logging records process launches, git commands, worktree resolution, session restore, notification/banner decisions, SwiftTerm `bell()` events (terminal attention bell), and optional manual terminal snapshots. When **global** debug logging is on, or when **at least one pane** is traced (see below), a ladybug button appears in the bottom-right corner of the main window. Clicking it opens the Debug Log sheet, which shows a timestamped, scrollable, copyable log.

This is useful for diagnosing permission prompts, PATH and worktree issues, **terminal bell and notification flow**, and other runtime behavior.

**Note:** The BEL byte (`0x07`) appears often in terminal streams as an **OSC sequence terminator**, not only as an attention bell. The app does not log raw PTY BEL traffic (that volume froze the UI); use `[bell]` lines when SwiftTerm surfaces a real bell.

## How to use

### Global debug logging

1. Open **Settings** (⌘,) and go to the **General** tab.
2. Enable the **Debug Logging** toggle.
3. Close Settings.
4. Reproduce the issue you want to diagnose (e.g., open a new pane, trigger a bell in a background pane).
5. Click the ladybug button in the bottom-right corner of the main window.
6. Review log entries. The footer shows how many lines are stored versus the buffer cap, and how many lines were ever dropped because of that cap.
7. Click **Copy** to copy the full log to the clipboard.
8. Click **Clear** to reset the log and drop counters, or **Close** to dismiss the sheet.
9. Disable debug logging in Settings when you are done (to avoid collecting unnecessary data).

### Per-pane tracing (without global logging)

1. Right-click a **pane** (not only the terminal body; the pane chrome works) and turn on **Trace this pane in debug log**.
2. The ladybug button appears even if **Settings → Debug Logging** is off.
3. Open the Debug Log from the ladybug and reproduce the issue; **pane-tagged** lines (notifications, banners, bell, process start for that pane, etc.) are recorded. Git commands, session restore, and other **global** instrumentation still require the Settings toggle.
4. Turn tracing off from the same context menu, or close the pane (tracing for that pane is cleared).

**While global Debug Logging is on**, the context menu does **not** show a separate trace toggle — it shows a short note that every pane is already included. Turn global logging **off** in Settings if you only want selected panes traced.

Turning **Debug Logging** off in Settings also **clears all per-pane trace selections** so stray tracing cannot keep running after you disable global logging.

### What **Settings → Debug Logging** controls

When enabled, it turns on **`DebugLogger.isEnabled`**, which records **app-wide** telemetry: session restore, git commands, worktree resolution, system info, **summarized** process launches (see below), and all **`[notify]`**, **`[bell]`**, and **`[banner]`** lines for every pane. The **ladybug** button is shown whenever global logging is on **or** at least one pane is traced.

Per-pane tracing only affects **pane-tagged** channels when global logging is **off** (bell, notifications, banner, and process start for that pane). It does **not** turn on git/session/worktree logging by itself.

## What is captured

| Event | Details logged |
|---|---|
| **Process start** | Shell path, arguments, working directory; environment as **var count** plus only the **first 12** `KEY=value` lines (values truncated more aggressively than other logs) so terminals are not blocked formatting huge env dumps |
| **Git command** | Git subcommand with full arguments and working directory |
| **Worktree resolution** | User input ref and resolved directory path (managed or not) |
| **Session restore** | Number of tabs restored, tab names, directories, and pane counts |
| **`[notify]`** | Wiring the bell to the notification pipeline; `addNotification` appended vs skipped (duplicate pane) |
| **`[bell]`** | SwiftTerm invoked `bell()` for a pane |
| **`[banner]`** | macOS Notification Center path: skipped (settings, UI tests, authorization) vs `UNUserNotificationCenter.add` success/failure |
| **`[telemetry]`** | Ring buffer dropped older lines or crossed a drop milestone summary |

Manual **Capture Terminal** still records the on-screen terminal buffer **per pane** when global logging is on or that pane is traced (capped), as before.

## Buffer and memory

- Lines are stored **in memory only** (no persistence across app restarts).
- **Per-pane tracing** is also **in memory only**; it is not saved to disk and is removed when the pane closes.
- The buffer holds at most **1000** entries (`DebugLogger.telemetryEntryCap`). Older entries are removed first.
- Each line is capped at **4000** characters (extra characters truncated with `…`).
- Every **50** dropped entries (from the cap, not from **Clear**), an extra summary line is recorded so you know telemetry was truncated.
- **Clear** resets both the visible log and the “total dropped” counter (it does not change which panes are traced).

## How to configure

- **Settings → General → Debug Logging** — global toggle on/off (persists via `~/Library/Application Support/agent-session-manager/debug-settings.json`).
- **Pane context menu → Trace this pane in debug log** — per-pane, in-memory only.

## Privacy note

Process-start lines include a **sample** of environment variables (first 12 keys, short value truncation). Other log types may still record longer snippets. If your environment contains secrets (API keys, tokens), they can still appear in the debug log. **Capture Terminal** can include on-screen CLI output. Review the log before sharing it with others, clear it after diagnosing your issue, or turn Debug Logging off when you are done.

## See also

- [notifications.md](notifications.md) — terminal bell handling, in-app notification dots, sidebar, and optional macOS banners.
