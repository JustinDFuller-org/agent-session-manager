# OpenCode CLI Support

Agent Session Manager supports [OpenCode](https://opencode.ai) as an alternative CLI tool alongside Claude Code, Codex, and Cursor.

## What It Does

When you create a pane with OpenCode selected, the app resolves or creates a worktree through the shared New Pane flow and launches `opencode` in that checkout with any enabled CLI flags.

OpenCode is an open-source terminal agent that can be used with many different model providers.

## How to Enable

OpenCode is disabled by default. To enable it:

1. Open **Settings** (⌘,)
2. Go to the **Tools** tab
3. Toggle **OpenCode** on

Once enabled, "OpenCode" appears as an option in the CLI picker when creating a new pane.

## Creating an OpenCode Pane

1. Open a tab pointing to your project directory
2. Press **⌘⇧N** (or click **+** in the pane area) to open the New Pane sheet
3. Select **OpenCode** in the CLI segmented picker
4. Enter a session name
5. Click **Open**

The pane launches `opencode` in the resolved checkout with any configured CLI flags appended.

## Configuring CLI Flags

OpenCode-specific flags can be enabled or disabled in **Settings → CLI Tools → OpenCode**. Enable OpenCode first, then configure which flags appear as toggles in the New Pane sheet.

### Available Flags

| Flag | Type | Description |
|------|------|-------------|
| `--agent` | string | Agent to use |
| `--continue` | boolean | Continue the last session |
| `--cors` | string | Additional browser origin(s) to allow CORS |
| `--fork` | boolean | Fork the session when continuing (use with `--continue` or `--session`) |
| `--hostname` | string | Hostname to listen on |
| `--mdns` | boolean | Enable mDNS discovery |
| `--mdns-domain` | string | Custom mDNS domain name |
| `--model` | string | Model to use in the form of `provider/model` |
| `--port` | string | Port to listen on |
| `--prompt` | string | Prompt to use |
| `--session` | string | Session ID to continue |

## Status Line

Agent Session Manager queries OpenCode's SQLite database to populate the status bar. See [opencode-status-line.md](opencode-status-line.md).

OpenCode can populate model, input/output token counts, session cost, session status (`idle` / `busy`), mode, worktree branch, duration, changed lines, profile, and PR. Version is currently missing, and the provider does not emit `retry`.

## Worktrees

OpenCode uses the same worktree resolution, external attachment, and cleanup flow as the other harnesses.

## Session Persistence

OpenCode pane names, options, and resolved checkout paths are saved in `sessions.json`. On relaunch, OpenCode panes are restored when their checkout still exists. The `--continue` flag is not automatically applied on restart.

See [agent-harness-feature-matrix.md](agent-harness-feature-matrix.md) for the cross-harness audit.
