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

The **Status** and **Mode** items are marked **OpenCode only** in Settings → Status Line.

## How It Works

OpenCode runs a local HTTP server when active. Agent Session Manager polls this server every 15 seconds using the workspace directory as the session filter (`x-opencode-directory` header).

**Port discovery** (tried in order):
1. Port `4096` (OpenCode's preferred default)
2. `~/.config/opencode/opencode.json` → `server.port` field (respects `XDG_CONFIG_HOME`)

If the server is unreachable, the status bar gracefully falls back to showing only the tool-agnostic data (version, branch, duration, PR).

## Enabling Status Items

1. Open **Settings → Status Line**
2. Click **+** in any row to add items
3. Items marked **OpenCode only** (purple badge) are populated exclusively when running an OpenCode pane

## Known Limitations

- **Custom ports via `--port` flag**: If you start OpenCode with `opencode --port <N>` and that port differs from the config file, the app cannot discover it automatically. Set `server.port` in `~/.config/opencode/opencode.json` to match.
- **Context window percentage**: OpenCode's API does not expose the model's maximum context window size, so the context percentage field is not available (only raw token counts are shown).
- **Session matching**: When multiple OpenCode sessions exist for the same directory, the most recently active session is used.
