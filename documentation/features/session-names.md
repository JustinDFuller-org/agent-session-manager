# Session Names

## What it does

When you create a new Claude pane, Agent Session Manager automatically passes `--name <tab>/<pane>` to Claude. This sets a display name for the session that appears in:

- `claude resume` — so you can find and resume the session by name
- The terminal title bar

For example, a pane named `auth-refactor` in a tab named `agent-session-manager` launches Claude with `--name 'agent-session-manager/auth-refactor'`.

## Override

To set a custom name, enable the **Session Name** flag in Settings → Harnesses. When `--name` (or `-n`) is present in your CLI options, the auto-injection is skipped and your explicit value is used instead.

## Disable

Toggle **Auto Session Name** off in Settings → Sessions. When disabled, no `--name` flag is injected automatically.

## Notes

- Auto-naming applies only to Claude panes. Codex and Cursor panes are unaffected.
- The name format is `<tab-name>/<pane-name>`. Single quotes in either name are shell-escaped.
