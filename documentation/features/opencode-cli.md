# OpenCode CLI Support

Agent Session Manager supports [OpenCode](https://opencode.ai) as an alternative CLI tool alongside Claude Code, Codex, and Cursor.

## What It Does

When you create a pane with the OpenCode CLI selected, the app launches `opencode` in your tab's working directory with any CLI flags you have enabled. Each pane runs an independent `opencode` TUI session.

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

The pane launches `opencode` in the tab's directory with any configured CLI flags appended.

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

Agent Session Manager queries the OpenCode HTTP server to populate the status bar for OpenCode panes. See [opencode-status-line.md](opencode-status-line.md) for the full list of available items and how port discovery works.

Items available for OpenCode panes include: model, input/output token counts, session cost, session status (idle/busy/retry), mode (code/ask/architect), version, worktree branch, duration, and PR.

## Worktrees

OpenCode panes do not create or manage git worktrees. The `opencode` process runs with its working directory set to the tab's root directory. If you need per-pane isolation, create a worktree via a Claude pane first, then open it as an existing worktree in an OpenCode pane.

## Session Persistence

OpenCode pane names are saved alongside Claude, Codex, and Cursor panes in `sessions.json`. On relaunch, OpenCode panes are restored and `opencode` is restarted in the tab's directory. The `--continue` flag is not automatically applied on restart.
