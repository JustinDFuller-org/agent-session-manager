# OpenCode Status Line

Agent Session Manager shows a configurable status bar at the bottom of each terminal pane. For OpenCode panes, the app queries the OpenCode local HTTP server to populate richer metrics than the baseline (version, branch, duration, PR).

## What Is Shown

When OpenCode is running and its server is reachable, the following status line items are available in addition to the tool-agnostic fields (version, worktree, branch, duration, PR):

| Item | Description |
|---|---|
| **Model** | The provider and model ID (e.g., `anthropic/claude-sonnet-4-5`) |
| **Input Tokens** | Total input tokens across all messages in the active session |
| **Output Tokens** | Total output tokens across all messages in the active session |
| **Cost** | Total cost in USD across all messages in the active session |
| **Status** | Current session state: `Idle`, `Busy`, or `Retry` |
| **Mode** | The mode of the latest message (e.g., `code`, `ask`, `architect`) |

**Model**, **Input Tokens**, **Output Tokens**, and **Cost** are marked **Claude + OpenCode** in Settings → Status Line — they work in both Claude Code and OpenCode panes. **Status** and **Mode** are marked **OpenCode only** — they are exclusive to OpenCode.

## How It Works

OpenCode stores all session data in a SQLite database at `~/.local/share/opencode/opencode.db` (respects `XDG_DATA_HOME`). Agent Session Manager queries this database every 15 seconds, filtering by the pane's working directory to find the most recently active session.

Token counts and cost are aggregated across all assistant messages in the session. Session status (idle/busy) is determined by whether the most recent assistant message has a completion timestamp.

If the database does not exist or no session matches the working directory, the status bar gracefully falls back to showing only the tool-agnostic data (branch, duration, PR).

## Enabling Status Items

1. Open **Settings → Status Line**
2. Click **+** in any row to add items
3. Items marked **Claude + OpenCode** (indigo badge) are populated for both Claude Code and OpenCode panes
4. Items marked **OpenCode only** (purple badge) are populated exclusively when running an OpenCode pane

## Known Limitations

- **Context window percentage**: OpenCode does not store the model's maximum context window size, so the context percentage field is not available (only raw token counts are shown).
- **Session matching**: When multiple OpenCode sessions exist for the same directory, the most recently updated session is used.
