# Cursor CLI Support

Agent Session Manager supports [Cursor](https://cursor.com/cli) as an alternative CLI tool alongside Claude Code and Codex.

## What It Does

When you create a pane with Cursor selected, the app resolves or creates a worktree through the shared New Pane flow and launches Cursor's `agent` command in that checkout with any enabled CLI flags.

## How to Enable

Cursor is disabled by default. To enable it:

1. Open **Settings** (⌘,)
2. Go to the **Harnesses** tab
3. Toggle **Cursor** on

Once enabled, "Cursor" appears as an option in the CLI picker when creating a new pane.

## Creating a Cursor Pane

1. Open a tab pointing to your project directory
2. Press **⌘P** (or click **+** in the pane area) to open the New Pane sheet
3. Select **Cursor** in the CLI segmented picker
4. Enter a session name
5. Click **Open**

The pane launches `agent` in the resolved checkout with any configured CLI flags appended.

## Configuring CLI Flags

Cursor-specific flags can be enabled or disabled in **Settings → Harnesses → Cursor**. Enable Cursor first, then configure which flags appear as toggles in the New Pane sheet.

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

Cursor uses app-owned baseline chips and an `afterAgentResponse` hook for model data. Agent Session Manager installs `~/.cursor/hooks.json` entries and passes each pane a private hook directory through `AGENT_SESSION_MANAGER_CURSOR_HOOK_DIR`; the pane ID remains available as `AGENT_SESSION_MANAGER_PANE_ID`. The baseline includes worktree, branch, duration, changed lines, version, profile, and PR data.

Cursor uses `beforeSubmitPrompt` and `stop` hooks for lifecycle activity state, plus the `stop` hook for attention notifications. Existing Cursor panes, including panes in hidden tabs, refresh their attention watcher when that setting changes.

## Session Persistence

Cursor pane names, options, and resolved checkout paths are saved in `sessions.json`. On relaunch, Cursor panes are restored when their checkout still exists.

See [agent-harness-feature-matrix.md]({{ '/documentation/features/agent-harness-feature-matrix/' | relative_url }}) for the cross-harness audit.
