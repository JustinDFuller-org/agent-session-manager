# Debug Logging

## What it does

Debug logging records every process launch, git command, worktree resolution, and session restore performed by Agent Session Manager. When enabled, a ladybug button appears in the bottom-right corner of the main window. Clicking it opens the Debug Log sheet, which shows a timestamped, scrollable, copyable log of all captured events.

This is primarily useful for diagnosing issues like unexpected file-access permission prompts, process environment problems, and worktree resolution errors.

## How to use

1. Open **Settings** (⌘,) and go to the **General** tab.
2. Enable the **Debug Logging** toggle.
3. Close Settings.
4. Reproduce the issue you want to diagnose (e.g., open a new pane).
5. Click the ladybug button in the bottom-right corner of the main window.
6. Review the log entries to see exactly what processes were launched, with what arguments, in what directories, and with what environment variables.
7. Click **Copy** to copy the full log to the clipboard.
8. Click **Clear** to reset the log, or **Close** to dismiss the sheet.
9. Disable debug logging in Settings when you are done (to avoid collecting unnecessary data).

## What is captured

| Event | Details logged |
|---|---|
| **Process start** | Shell path, arguments, working directory, and all environment variable names/values (values truncated to 200 characters) |
| **Git command** | Git subcommand with full arguments and working directory |
| **Worktree resolution** | User input ref and resolved directory path (managed or not) |
| **Session restore** | Number of tabs restored, tab names, directories, and pane counts |

## How to configure

- **Settings → General → Debug Logging** — toggle on/off.
- The setting persists across app launches via `~/Library/Application Support/agent-session-manager/debug-settings.json`.
- The log buffer is in-memory only and does not persist across app restarts.

## Privacy note

Environment variable values are logged in full (up to 200 characters per value). If your environment contains secrets (API keys, tokens), those will appear in the debug log. Review the log before sharing it with others, or clear the log after diagnosing your issue.

## See also

- [notifications.md](notifications.md) — terminal bell handling, in-app notification dots, sidebar, and optional macOS banners (separate from the debug log).
