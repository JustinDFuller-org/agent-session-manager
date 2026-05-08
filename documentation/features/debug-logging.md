# Debug Logging

## What it does

Debug logging records process launches, git commands, worktree resolution, session restore, notification/banner decisions, terminal bell / PTY BEL events, and optional manual terminal snapshots. When enabled, a ladybug button appears in the bottom-right corner of the main window. Clicking it opens the Debug Log sheet, which shows a timestamped, scrollable, copyable log.

This is useful for diagnosing permission prompts, PATH and worktree issues, **terminal bell and notification flow**, and other runtime behavior.

## How to use

1. Open **Settings** (⌘,) and go to the **General** tab.
2. Enable the **Debug Logging** toggle.
3. Close Settings.
4. Reproduce the issue you want to diagnose (e.g., open a new pane, trigger a bell in a background pane).
5. Click the ladybug button in the bottom-right corner of the main window.
6. Review log entries. The footer shows how many lines are stored versus the buffer cap, and how many lines were ever dropped because of that cap.
7. Click **Copy** to copy the full log to the clipboard.
8. Click **Clear** to reset the log and drop counters, or **Close** to dismiss the sheet.
9. Disable debug logging in Settings when you are done (to avoid collecting unnecessary data).

## What is captured

| Event | Details logged |
|---|---|
| **Process start** | Shell path, arguments, working directory, and all environment variable names/values (values truncated to 200 characters) |
| **Git command** | Git subcommand with full arguments and working directory |
| **Worktree resolution** | User input ref and resolved directory path (managed or not) |
| **Session restore** | Number of tabs restored, tab names, directories, and pane counts |
| **`[notify]`** | Wiring the bell to the notification pipeline; `addNotification` appended vs skipped (duplicate pane) |
| **`[bell]`** | SwiftTerm invoked `bell()` for a pane |
| **`[pty]`** | Raw PTY chunk contained a BEL byte (`0x07`); short hex preview around that byte (may include escape bytes—still bounded) |
| **`[banner]`** | macOS Notification Center path: skipped (settings, UI tests, authorization) vs `UNUserNotificationCenter.add` success/failure |
| **`[telemetry]`** | Ring buffer dropped older lines or crossed a drop milestone summary |

Manual **Capture Terminal** still records the current on-screen terminal buffer per pane (capped), as before.

## Buffer and memory

- Lines are stored **in memory only** (no persistence across app restarts).
- The buffer holds at most **1000** entries (`DebugLogger.telemetryEntryCap`). Older entries are removed first.
- Each line is capped at **4000** characters (extra characters truncated with `…`).
- Every **50** dropped entries (from the cap, not from **Clear**), an extra summary line is recorded so you know telemetry was truncated.
- **Clear** resets both the visible log and the “total dropped” counter.

## How to configure

- **Settings → General → Debug Logging** — toggle on/off.
- The setting persists across app launches via `~/Library/Application Support/agent-session-manager/debug-settings.json`.

## Privacy note

Environment variable values are logged in full (up to 200 characters per value). If your environment contains secrets (API keys, tokens), those will appear in the debug log. `[pty]` hex previews may show nearby escape sequences or output from the CLI. Review the log before sharing it with others, or clear the log after diagnosing your issue.

## See also

- [notifications.md](notifications.md) — terminal bell handling, in-app notification dots, sidebar, and optional macOS banners.
