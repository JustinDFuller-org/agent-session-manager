# Codex CLI Support

Agent Session Manager supports [Codex](https://developers.openai.com/codex) as an alternative CLI tool alongside Claude Code and Cursor.

## What It Does

When you create a pane with the Codex CLI selected, the app launches `codex` in your tab's working directory with any CLI flags you have enabled. Each pane runs an independent `codex` session.

## How to Enable

Codex is disabled by default. To enable it:

1. Open **Settings** (⌘,)
2. Go to the **Tools** tab
3. Toggle **Codex** on

Once enabled, "Codex" appears as an option in the CLI picker when creating a new pane.

## Creating a Codex Pane

1. Open a tab pointing to your project directory
2. Press **⌘⇧N** (or click **+** in the pane area) to open the New Pane sheet
3. Select **Codex** in the CLI segmented picker
4. Enter a session name
5. Click **Open**

The pane launches `codex` in the tab's directory with any configured CLI flags appended.

## Configuring CLI Flags

Codex-specific flags can be enabled or disabled in **Settings → CLI Tools → Codex**. Enable Codex first, then configure which flags appear as toggles or text fields in the New Pane sheet.

### Available Flags

| Flag | Type | Description |
|------|------|-------------|
| `--ask-for-approval` | string | Control approval timing: `untrusted`, `on-request`, or `never` |
| `--config` | string | Override configuration values (`key=value`, JSON-parsed if possible) |
| `--dangerously-bypass-approvals-and-sandbox` | boolean | Skip all approval prompts and sandbox restrictions (dangerous) |
| `--disable` | string | Force-disable a named feature flag |
| `--enable` | string | Force-enable a named feature flag |
| `--image` | string | Attach image files to the initial prompt |
| `--model` | string | Override the configured model for this session |
| `--no-alt-screen` | boolean | Disable alternate screen mode for the TUI |
| `--oss` | boolean | Use a local open source provider (Ollama) |
| `--profile` | string | Load a named configuration profile |
| `--sandbox` | string | Sandbox policy: `read-only`, `workspace-write`, or `danger-full-access` |
| `--search` | boolean | Enable live web search during the session |

## Status Line

Codex does not have documented status line hook support. The status bar is not populated for Codex panes. If Codex adds status line support in a future release, this can be wired up similarly to Claude's `StatusLineMonitor`.

## Session Persistence

Codex pane names and settings are saved alongside Claude and Cursor panes in `sessions.json`. On relaunch, Codex panes are restored and `codex` is restarted in the tab's directory.
