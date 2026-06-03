# Codex CLI Support

Agent Session Manager supports [Codex](https://developers.openai.com/codex) alongside Claude Code and Cursor.

## What It Does

When you create a pane with Codex selected, the app resolves or creates a worktree through the shared New Pane flow and launches `codex` in that checkout with any enabled CLI flags.

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

The pane launches `codex` in the resolved checkout with any configured CLI flags appended.

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

Codex uses app-owned baseline status plus a version-gated local Codex provider.

Baseline facts populate from the app side: worktree, branch, duration, changed lines, version, profile, and PR data. For Codex `0.136.x`, the provider also reads `~/.codex/state_5.sqlite` read-only to find the active thread for the pane working directory, preferring non-archived rows closest to the pane process start time. It then tails that thread's rollout JSONL for model, token, context, and rate-limit facts. Unsupported facts, such as cost, are omitted for Codex panes.

Unknown Codex versions degrade to baseline facts plus model/version from SQLite when available. Rollout parsing is treated as an internal, versioned integration and ignores content-bearing records. Provider traces record bounded selection, rollout, and field-presence diagnostics without logging prompts, transcript lines, auth data, or environment values.

## Session Persistence

Codex pane names, options, and resolved checkout paths are saved in `sessions.json`. On relaunch, Codex panes are restored when their checkout still exists.

See [agent-harness-feature-matrix.md](agent-harness-feature-matrix.md) for the cross-harness audit.
