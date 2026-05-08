# Debug Logging

## What it does

Debug logging appends diagnostics to a **trace file on disk** (not an in-memory buffer). It records process launches, git commands, worktree resolution, session restore, notification/banner decisions, SwiftTerm `bell()` / OSC 777 attention events, optional **streaming** on-screen terminal text when capture is enabled (debounced, on PTY output), and optional **manual terminal snapshots** from the debug sheet.

When **global debug logging** is on, or when at least one pane is **traced** (events) or has **per-pane terminal capture** enabled, a ladybug button appears in the bottom-right corner of the main window. It opens the **Debug Tracing** sheet with the trace path, **Reveal in Finder**, **Copy Path**, **Capture Terminal Snapshots**, **Truncate Trace File**, and **Report Bug**.

Global debug also appends **── Notification Environment ──** (UNUserNotificationCenter authorization and delivery settings, plus the in-app banner toggle) after system info, and again when that toggle changes while debug logging is on. In-flight requests log `[banner] notification settings snapshot`, `requestAuthorization finished`, **`willPresent`** (when a banner is about to show while the app is foreground), `[banner] postPaneAttentionIfNeeded begin`, **`addNotification` / `clearNotification` / `focusPane` / `navigateTo`** (sidebar / banner handoff).

**Note:** The BEL byte (`0x07`) often terminates OSC sequences; see [notifications.md](notifications.md) for bell vs OSC 777.

## Settings (General → Debug)

| Setting | Meaning |
|--------|---------|
| **Debug Logging** | Master switch: all global events (git, session restore, worktree resolution, system info sample, every pane’s process starts, notify/bell/banner lines) append to the trace file. |
| **Trace file path** | Empty = default `debug-trace.log` under Application Support. `~` is expanded. |
| **Max trace file size** | When the file would grow beyond this, **older bytes are removed from the beginning** of the file (with a truncation banner line). |
| **Include terminal snapshots** | When global debug is on, eligible panes **stream** on-screen terminal text into the trace file (debounced) as output arrives, and **Capture Terminal Snapshots** in the debug sheet can dump **all** eligible panes’ buffers on demand. If this is off globally, you can still enable capture per pane from the pane context menu (streaming + sheet snapshots for that pane only). |

Persistence: `~/Library/Application Support/agent-session-manager/debug-settings.json` (JSON object; legacy `true`/`false` files still load as “enabled only”).

## Pane context menu

- **Trace this pane (events to trace file)** — when global debug is **off**, record this pane’s events (process start, bell, notify, banner decisions, etc.) to the file with `[tab: …] [pane: …]` prefixes on each line.
- **Include this pane’s terminal in trace captures** — enable **streaming** and the same **pane-attributed** event lines as tracing (bells, `addNotification`, macOS banner flow, etc.) for this pane, even when global debug and “trace this pane” are **off**. When global debug and global terminal snapshots are both on, every pane already gets full diagnostics and streaming, so the per-pane terminal toggle is disabled in the menu.

### Pane diagnostics (events + terminal)

Any pane that is **globally debugged**, **event-traced**, or has **terminal capture** enabled receives `[notify]` / `[banner]` / `[bell]` and **process start** lines for that pane in the trace file. Turning on only **terminal capture** (without global debug) is enough to correlate terminal streams with the notification pipeline for that pane.

## Streaming terminal text

When a pane is eligible for terminal capture, each burst of host (PTY → emulator) output schedules a **debounced** flush (~400 ms): if the **visible** terminal buffer changed, a `── Terminal stream: …──` block is appended (same per-line cap as manual snapshots). Identical consecutive screens are skipped to limit noise and file growth.

## Capture Terminal Snapshots

Runs from the Debug Tracing sheet. Writes a **one-shot** capped snapshot of each eligible pane’s terminal buffer to the file (`── Terminal Content: …──`). Eligibility is the same as streaming: **(global debug + global include terminal)** **or** the pane is in the per-pane terminal capture set.

## Report Bug

Opens a GitHub **new issue** URL with a short body: **system summary** (redacted env-style keys) and the **trace file path** — not the full trace. Inspect the file locally before sharing.

## Privacy

Process-start logging still samples environment variables (first N lines, truncated values). Streaming and snapshots can contain secrets from on-screen output. **Review and redact** the trace file before posting it publicly.

## See also

- [notifications.md](notifications.md) — bell and optional macOS banners.
- [panes.md](panes.md) — shells, worktrees, and terminals.
