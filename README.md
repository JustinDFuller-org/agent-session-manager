# agent-session-manager
Keeps your agents (Claude, Codex, Cursor, etc.) managed in a window optimized for multi-agent workflows.

## Features

**Tabs** represent a working directory. Each tab has a name and a root directory. Switch between them with ⌘1–⌘9.

**Panes** are terminal sessions inside a tab. Creating a pane launches `claude --worktree <name>` in an isolated git worktree. Panes auto-arrange in a grid (1×1 → 2×1 → 2×2 → 3×2 → 3×3) as you add more.

**Status line** — each pane shows a live status bar at the bottom with Claude session data: model, worktree name, cost, context window usage, and more. All 24 available fields are configurable in Settings → Status Line.

**CLI options** — 62 Claude CLI flags can be enabled/disabled in Settings → CLI Options. Enabled flags appear as toggles and text fields in the New Pane sheet. Custom flags are also supported.

**Session persistence** — tabs and pane names are saved and restored on relaunch. Any pane whose worktree still exists on disk is restarted automatically.

**Keyboard shortcuts:**
- ⌘T — new tab
- ⌘⇧N — new pane
- ⌘W — close active pane
- ⌘1–⌘9 — switch to tab by index
