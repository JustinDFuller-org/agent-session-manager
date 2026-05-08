# Debug Logging

## What it does

Debug logging appends diagnostics to a **trace file on disk** (not an in-memory buffer). It records process launches, git commands, worktree resolution, session restore, notification/banner decisions, SwiftTerm `bell()` / OSC 777 attention events, and optional **terminal snapshots** when you capture them.

When **global debug logging** is on, or when at least one pane is **traced** (events) or has **per-pane terminal capture** enabled, a ladybug button appears in the bottom-right corner of the main window. It opens the **Debug Tracing** sheet with the trace path, **Reveal in Finder**, **Copy Path**, **Capture Terminal Snapshots**, **Truncate Trace File**, and **Report Bug**.

**Note:** The BEL byte (`0x07`) often terminates OSC sequences; see [notifications.md](notifications.md) for bell vs OSC 777.

## Settings (General → Debug)

| Setting | Meaning |
|--------|---------|
| **Debug Logging** | Master switch: all global events (git, session restore, worktree resolution, system info sample, every pane’s process starts, notify/bell/banner lines) append to the trace file. |
| **Trace file path** | Empty = default `debug-trace.log` under Application Support. `~` is expanded. |
| **Max trace file size** | When the file would grow beyond this, **older bytes are removed from the beginning** of the file (with a truncation banner line). |
| **Include terminal snapshots** | When global debug is on, **Capture Terminal Snapshots** in the debug sheet can dump **all** panes’ on-screen terminal text into the file. If this is off, you can still enable terminal capture **per pane** from the pane context menu. |

Persistence: `~/Library/Application Support/agent-session-manager/debug-settings.json` (JSON object; legacy `true`/`false` files still load as “enabled only”).

## Pane context menu

- **Trace this pane (events to trace file)** — when global debug is **off**, record this pane’s events (process start, bell, notify, etc.) to the file with `[tab: …] [pane: …]` prefixes on each line.
- **Include this pane’s terminal in trace captures** — allow **Capture Terminal Snapshots** to include this pane even when global “include terminal” is off. Disabled when global debug and global terminal snapshots are both on (every pane is already included).

## Capture Terminal Snapshots

Runs from the Debug Tracing sheet. Writes a capped snapshot of each eligible pane’s terminal buffer to the file. Eligibility: **(global debug + global include terminal)** **or** the pane is in the per-pane terminal capture set.

## Report Bug

Opens a GitHub **new issue** URL with a short body: **system summary** (redacted env-style keys) and the **trace file path** — not the full trace. Inspect the file locally before sharing.

## Privacy

Process-start logging still samples environment variables (first N lines, truncated values). Terminal snapshots can contain secrets from on-screen output. **Review and redact** the trace file before posting it publicly.

## See also

- [notifications.md](notifications.md) — bell and optional macOS banners.
- [panes.md](panes.md) — shells, worktrees, and terminals.
