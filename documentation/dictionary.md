# Agent Session Manager — Project Dictionary

Canonical glossary of domain terms used across this codebase. One entry per concept; each includes a 1–2 line definition and a source pointer for deeper reading.

**Contributing:** keep entries alphabetical; add a source pointer (code path and/or feature doc) per term.

---

- **Chip** — a single item in the status line showing one fact (model name, cost, context percentage, etc.). Chips are arranged in rows and are configurable per-profile. See `documentation/features/status-line.md`.

- **CLI options / flags** — a library of toggleable Claude CLI flags surfaced in the New Pane sheet and stored per-profile. Model: `Models/CLIOptionConfig.swift`.

- **CLI type** — the agent tool a pane runs: `claude`, `codex`, `cursor`, `opencode`, or the internal `shell` type. Model: `Models/Pane.swift` (`CLIType`).

- **Grid layout** — the auto-arrangement algorithm that places panes in a tab: 1×1 → 2×1 → 2×2 → 3×2 → 3×3. Model: `Models/GridLayout.swift`.

- **Managed worktree** — a git worktree that ASM creates and owns, placed under `<repo>/.agent-session-manager/worktrees/<name>`. See `documentation/features/worktree-creation.md`.

- **Observability dashboard** — the in-app waterfall timeline that renders OpenTelemetry spans grouped by tab and pane. See `documentation/features/observability-dashboard.md`.

- **Pane** — a terminal session inside a tab that runs an AI agent CLI. Panes are the primary unit of work. See `documentation/features/panes.md`, `Models/Pane.swift`.

- **PR tracking** — detects the GitHub PR for the active branch and surfaces its CI status as a chip with a detail popover. See `documentation/features/pr-tracking.md`.

- **Profile** — a saved, named set of CLI flags, environment variables, CLI type, and optional status-line configuration that pre-fills the New Pane sheet. See `documentation/features/profiles.md`, `Models/Profile.swift`.

- **Session name** — the `--name <tab>/<pane>` argument passed to the agent so it can resume a prior conversation and display a meaningful title. See `documentation/features/session-names.md`.

- **Session persistence** — the mechanism that saves and restores tabs and pane names across app launches via `sessions.json`. Controller: `Controllers/SessionPersistence.swift`.

- **Status line** — a configurable bar at the bottom of each pane composed of rows of chips. See `documentation/features/status-line.md`.

- **Tab** — a named working-directory container that holds one or more panes; switch with ⌘1–⌘9. Model: `Models/Tab.swift`.

- **Tab loading indicator** — the green pulsing dot shown on a tab when any of its panes has a running process. See `documentation/features/tab-loading-indicator.md`.

- **Terminal Purity** — the invariant that the terminal surface shows only the agent's own UI output, never ASM plumbing or injected text. Defined and enforced in `AGENTS.md`.

- **Tracing** — OpenTelemetry spans written to per-pane JSONL files under `traces/<tab-id8>/<pane-id8>.jsonl`; retained for one day. See `documentation/features/tracing.md`, `Models/TracingService.swift`.

- **Worktree** — a git worktree backing a tab's working directory. A worktree may be managed (created by ASM) or pre-existing. See **Managed worktree**; model: `Models/Tab.swift`.
