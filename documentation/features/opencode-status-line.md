# OpenCode Status Line

> For the general status line feature (item catalog, invariants, row configuration), see [status-line.md](status-line.md).

Agent Session Manager shows a configurable status bar at the bottom of each terminal pane. For OpenCode panes, the app queries the OpenCode SQLite database to populate richer metrics than the baseline (worktree, branch, duration, lines added/removed, profile, PR).

## OpenCode-Specific Items

The following items are exclusive to OpenCode panes or shared with Claude Code:

| Item | Availability | Description |
|---|---|---|
| **Model** | Claude + OpenCode | The provider and model ID (e.g., `anthropic/claude-sonnet-4-5`) |
| **Input Tokens** | Claude + OpenCode | Total input tokens across all messages in the active session |
| **Output Tokens** | Claude + OpenCode | Total output tokens across all messages in the active session |
| **Cost** | Claude + OpenCode | Total cost in USD across all messages in the active session |
| **Status** | OpenCode only | Current session state: `Idle` or `Busy` |
| **Mode** | OpenCode only | The mode of the latest message (e.g., `code`, `ask`, `architect`) |

Items marked **Claude + OpenCode** (indigo badge) work in both Claude Code and OpenCode panes. Items marked **OpenCode only** (purple badge) are exclusive to OpenCode.

**Lines Added** and **Lines Removed** are app-computed from `git diff --shortstat HEAD` for all pane types including OpenCode — see [status-line.md](status-line.md#i3-lines-addedremoved-means-vs-head).

## How It Works

OpenCode stores all session data in a SQLite database at `~/.local/share/opencode/opencode.db` (respects `XDG_DATA_HOME`). Agent Session Manager queries this database every 15 seconds, filtering by the pane's working directory to find the most recently active session.

Token counts and cost are aggregated across all assistant messages in the session. Session status (idle/busy) is determined by whether the most recent assistant message has a completion timestamp.

If the database does not exist or no session matches the working directory, the status bar gracefully falls back to tool-agnostic data such as branch, duration, changed lines, profile, and PR.

## Enabling Status Items

1. Open **Settings → Status Line**
2. Click **+** in any row to add items
3. Items marked **Claude + OpenCode** (indigo badge) are populated for both Claude Code and OpenCode panes
4. Items marked **OpenCode only** (purple badge) are populated exclusively when running an OpenCode pane

## Known Limitations

- **Context window percentage**: OpenCode does not store the model's maximum context window size, so the context percentage field is not available (only raw token counts are shown).
- **Version**: the OpenCode provider does not currently populate the version chip.
- **Retry status**: the renderer recognizes `retry`, but the OpenCode provider currently emits only `idle` or `busy`.
- **Session matching**: When multiple OpenCode sessions exist for the same directory, the most recently updated session is used.
