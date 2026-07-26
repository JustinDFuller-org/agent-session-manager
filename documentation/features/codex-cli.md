# Codex CLI Support

Agent Session Manager supports [Codex](https://developers.openai.com/codex) alongside Claude Code and Cursor.

## What It Does

When you create a pane with Codex selected, the app resolves or creates a worktree through the shared New Pane flow and launches `codex` in that checkout with any enabled CLI flags.

## How to Enable

Codex is disabled by default. To enable it:

1. Open **Settings** (⌘,)
2. Go to the **Harnesses** tab
3. Toggle **Codex** on

Once enabled, "Codex" appears as an option in the CLI picker when creating a new pane.

## Creating a Codex Pane

1. Open a tab pointing to your project directory
2. Press **⌘P** (or click **+** in the pane area) to open the New Pane sheet
3. Select **Codex** in the CLI segmented picker
4. Enter a session name
5. Click **Open**

The pane launches `codex` in the resolved checkout with any configured CLI flags appended.

## Configuring CLI Flags

Codex-specific flags can be enabled or disabled in **Settings → Harnesses → Codex**. Enable Codex first, then configure which flags appear as toggles or text fields in the New Pane sheet.

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

Baseline facts populate from the app side: worktree, branch, duration, changed lines, version, profile, and PR data. Codex panes launch with app-owned lifecycle hooks that write a pane-scoped session record containing the Codex `session_id`, `cwd`, model, and `transcript_path`. The provider starts baseline polling immediately and keeps watching the hook record path until the first valid pane/tab record arrives, even after the startup window. It then pins the session id/transcript path for the pane lifetime and tails only that transcript for model, token, context, and rate-limit facts. Unsupported facts, such as cost, are omitted for Codex panes.

For Codex `0.136.x`, `~/.codex/state_5.sqlite` is optional enrichment by exact session id or exact transcript/rollout path only. The provider never selects a session by latest same-cwd row. Unknown Codex versions degrade to baseline facts plus hook model/version when available. Rollout parsing is treated as an internal, versioned integration and ignores content-bearing records. Input/output token chips use cumulative `total_token_usage`; context chips use `last_token_usage.total_tokens` divided by `model_context_window`. Provider traces record bounded hook binding, SQLite enrichment, transcript tailing, and field-presence diagnostics without logging prompts, transcript lines, auth data, or environment values.

## Session Persistence

Codex pane names, options, and resolved checkout paths are saved in `sessions.json`. On relaunch, Codex panes are restored when their checkout still exists.

See [agent-harness-feature-matrix.md]({{ '/documentation/features/agent-harness-feature-matrix/' | relative_url }}) for the cross-harness audit.
