# Cursor CLI Support

Agent Session Manager supports [Cursor](https://cursor.com/cli) as an alternative CLI tool alongside Claude Code and Codex.

## What It Does

When you create a pane with the Cursor CLI selected, the app launches `cursor` in your tab's working directory with any CLI flags you have enabled. Each pane runs an independent `cursor` session.

## How to Enable

Cursor is disabled by default. To enable it:

1. Open **Settings** (⌘,)
2. Go to the **Tools** tab
3. Toggle **Cursor** on

Once enabled, "Cursor" appears as an option in the CLI picker when creating a new pane.

## Creating a Cursor Pane

1. Open a tab pointing to your project directory
2. Press **⌘⇧N** (or click **+** in the pane area) to open the New Pane sheet
3. Select **Cursor** in the CLI segmented picker
4. Enter a session name
5. Click **Open**

The pane launches `cursor` in the tab's directory with any configured CLI flags appended.

## Configuring CLI Flags

Cursor-specific flags can be enabled or disabled in **Settings → CLI Tools → Cursor**. Enable Cursor first, then configure which flags appear as toggles in the New Pane sheet.

### Available Flags

| Flag | Type | Description |
|------|------|-------------|
| `--api-key` | string | API key for authentication (alternative to `CURSOR_API_KEY` env var) |
| `--approve-mcps` | boolean | Automatically approve all MCP servers |
| `--continue` | boolean | Continue the previous session (alias for `--resume=-1`) |
| `--force` | boolean | Force allow commands unless explicitly denied |
| `--header` | string | Add a custom header to agent requests (`Name: Value`) |
| `--list-models` | boolean | List all available models and exit |
| `--mode` | string | Agent mode: `plan` or `ask` (default is agent) |
| `--model` | string | Model to use for this session |
| `--output-format` | string | Output format when using `--print`: `text`, `json`, or `stream-json` |
| `--plan` | boolean | Start in plan mode (shorthand for `--mode=plan`) |
| `--print` | boolean | Print responses to console for non-interactive use |
| `--resume` | string | Resume a chat session by ID |
| `--sandbox` | string | Set sandbox mode: `enabled` or `disabled` |
| `--stream-partial-output` | boolean | Stream partial output as text deltas (requires `--print` + `stream-json`) |
| `--trust` | boolean | Trust the workspace without prompting (headless mode only) |
| `--workspace` | string | Workspace directory to use for this session |
| `--yolo` | boolean | Alias for `--force` |

## Status Line

Cursor does not have documented status line hook support. The status bar is not populated for Cursor panes. If Cursor adds status line support in a future release, this can be wired up similarly to Claude's `StatusLineMonitor`.

## Session Persistence

Cursor pane names and settings are saved alongside Claude and Codex panes in `sessions.json`. On relaunch, Cursor panes are restored and `cursor` is restarted in the tab's directory.
