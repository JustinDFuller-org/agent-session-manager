<img width="1600" height="auto" alt="image" src="assets/img/hero.png" />

<br />
<br />

Keeps your agents (Claude, Codex, Cursor, etc.) managed in a window optimized for multi-agent workflows.

## Features

**Tabs** represent a working directory. Each tab has a name and a root directory. Switch between them with ⌘1–⌘9.

**Panes** are terminal sessions inside a tab. Creating a pane launches the selected harness (Claude, Cursor, or Codex) in an isolated git worktree. Panes auto-arrange in a grid (1×1 → 2×1 → 2×2 → 3×2 → 3×3) as you add more.

**Status line** — each pane shows a live status bar at the bottom with Claude session data: model, worktree name, cost, context window usage, and more. All 32 available fields are configurable in Settings → Status Line.

**CLI options** — 64 Claude CLI flags can be enabled/disabled in Settings → Harnesses. Enabled flags appear as toggles and text fields in the New Pane sheet. Custom flags are also supported.

**Session persistence** — tabs and pane names are saved and restored on relaunch. Any pane whose worktree still exists on disk is restarted automatically.

**Keyboard shortcuts:**
- ⌘T — new tab
- ⌘P — new pane
- ⌘W — close active pane
- ⌘K — close active tab
- ⌘1–⌘9 — switch to tab by index

**Observability / Debugging** — unified logs (Console.app / `log stream`) and Instruments signposts are always on, no setup needed. Enable **Settings → Debug → Enable Debug Mode** for durable trace/invariant JSONL files and the Trace (`⌘⇧D`) and Invariant (`⌘⇧I`) dashboards.
