# Agent Harness Feature Matrix

This is the canonical, code-observed audit of Agent Session Manager integration points for Claude Code, Cursor, Codex, and OpenCode as of **May 30, 2026**. It describes the app implementation, not upstream CLI feasibility. The internal `.shell` pane type is excluded.

## Legend

| Status | Meaning |
|---|---|
| **Implemented** | Wired end to end in Agent Session Manager |
| **Partial** | Present, but with a known limitation or lifecycle gap |
| **Missing** | Not implemented in Agent Session Manager |
| **N/A** | Intentionally not applicable to that harness |

## Product Surface

| Surface | Claude Code | Cursor | Codex | OpenCode | Notes |
|---|---|---|---|---|---|
| Tool detection | Implemented | Implemented | Implemented | Implemented | `CLIToolDetector` probes `claude`, `agent`, `codex`, and `opencode` in the selected interactive shell. |
| Tool activation | Implemented | Implemented | Implemented | Implemented | Settings persist active harnesses; only active harnesses appear in New Pane. |
| Launch command | Implemented | Implemented | Implemented | Implemented | Launches `claude --settings ...`, `agent`, `codex`, or `opencode` in the resolved checkout. |
| Configurable CLI options | Implemented | Implemented | Implemented | Implemented | Each harness has a separate catalog. See the harness-specific CLI guides linked below. |
| Configurable environment variables | Implemented | N/A | N/A | N/A | The user-facing environment-variable catalog is Claude-specific. Cursor also receives the internal `AGENT_SESSION_MANAGER_PANE_ID`. |
| Profiles: CLI options | Implemented | Implemented | Implemented | Implemented | Profiles store a harness type and harness-specific CLI options. |
| Profiles: environment variables | Implemented | N/A | N/A | N/A | Profile environment variables are Claude-specific. |
| Worktree resolution | Implemented | Implemented | Implemented | Implemented | New Pane passes every harness through `Tab.resolveOrAttachWorktree`. |
| Loading overlay during worktree setup | Implemented | Implemented | Implemented | Implemented | `addPaneWithLoadingState` precedes async Git setup for every harness. |
| External worktree attachment | Implemented | Implemented | Implemented | Implemented | Existing paths from `git worktree list --porcelain` can be reused. |
| Managed worktree cleanup | Implemented | Implemented | Implemented | Implemented | Cleanup is based on pane worktree ownership, not harness type. |
| Session restore | Implemented | Implemented | Implemented | Implemented | Persisted resolved checkout directories are restored for every harness when they still exist. |
| Continue on app restart | Implemented | N/A | N/A | N/A | Automatic restore-time `--continue` injection is Claude-only. |
| Auto session names | Implemented | N/A | N/A | N/A | Automatic `--name '<tab>/<pane>'` injection is Claude-only. |
| Restart existing process | Partial | Partial | Partial | Partial | Controller replacement does not rewire notification callbacks. |
| Quick refresh and continue | Partial | Partial | Partial | Partial | Monitor/controller replacement does not rewire notifications. Cursor also loses `AGENT_SESSION_MANAGER_PANE_ID`. |
| Refresh with new settings | Partial | Partial | Partial | Partial | Replaces monitor/controller without rewiring notifications. Cursor does restore its pane ID on this path. |
| Rich status provider | Implemented | Partial | Missing | Partial | Claude uses `statusLine`; Cursor adds hook model data; Codex has baseline app data only; OpenCode reads SQLite. |
| Shared baseline status | Implemented | Implemented | Implemented | Implemented | Worktree, branch, duration, lines changed, PR, and profile chips are app-owned where data is available. Cursor and Codex fetch versions. |
| Native attention integration | Implemented | Partial | Missing | Missing | Claude uses `Notification`; Cursor uses `stop`, but setting changes do not refresh existing panes. |
| Shared terminal attention | Implemented | Implemented | Implemented | Implemented | BEL and OSC 777 flow through `TerminalController`. |
| Notification sidebar and banners | Partial | Partial | Partial | Partial | Delivery exists, but new-pane and controller-replacement lifecycle gaps can prevent callbacks from being attached. |
| Notification persistence | Implemented | Implemented | Implemented | Implemented | Pending in-app notifications are stored in `sessions.json`. |
| GitHub PR tracking | Implemented | Implemented | Implemented | Implemented | `PRTrackingCoordinator` is harness-independent. |
| PR merged notifications | Partial | Partial | Partial | Partial | Provider delivery exists for every monitor, but notification callback rewiring has the lifecycle gaps above. |
| Observability and trace dashboard | Implemented | Implemented | Implemented | Implemented | Trace recording and dashboard grouping are app-level features. |

## Status Chips

The catalog controls whether a chip can be selected for a harness. A selectable chip can still render `—` when its provider does not populate the field.

| Chip ID | Claude Code | Cursor | Codex | OpenCode | Source or gap |
|---|---|---|---|---|---|
| `model` | Implemented | Implemented | **Missing** | Implemented | Claude hook JSON; Cursor `afterAgentResponse` hook; OpenCode SQLite. Codex provider does not populate model data. |
| `worktree` | Implemented | Implemented | Implemented | Implemented | App-owned checkout directory plus Git branch. |
| `cost` | Implemented | N/A | N/A | Implemented | Claude hook JSON; OpenCode SQLite aggregate. |
| `context` | Implemented | N/A | N/A | N/A | Claude hook JSON percentage. |
| `effort` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `thinking` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `vimMode` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `agentName` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `sessionName` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `linesAdded` | Implemented | Implemented | Implemented | Implemented | App-owned `git diff --shortstat HEAD`. |
| `linesRemoved` | Implemented | Implemented | Implemented | Implemented | App-owned `git diff --shortstat HEAD`. |
| `duration` | Implemented | Implemented | Implemented | Implemented | App-owned process duration. |
| `contextRemaining` | Implemented | N/A | N/A | N/A | Claude hook JSON percentage. |
| `inputTokens` | Implemented | N/A | N/A | Implemented | Claude hook JSON; OpenCode SQLite aggregate. |
| `outputTokens` | Implemented | N/A | N/A | Implemented | Claude hook JSON; OpenCode SQLite aggregate. |
| `rate5h` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `rate7d` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `rate5hReset` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `rate7dReset` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `version` | Implemented | Implemented | Implemented | **Missing** | Claude hook JSON; Cursor and Codex run `<command> --version`. OpenCode provider always returns `nil`. |
| `outputStyle` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `exceeds200k` | Implemented | N/A | N/A | N/A | Claude hook JSON. |
| `sessionStatus` | N/A | N/A | N/A | **Partial** | OpenCode SQLite emits `idle` or `busy`; the renderer supports `retry`, but the provider never emits it. |
| `openCodeMode` | N/A | N/A | N/A | Implemented | OpenCode SQLite latest assistant message. |
| `pr` | Implemented | Implemented | Implemented | Implemented | App-level GitHub CLI polling. |
| `profileName` | Implemented | Implemented | Implemented | Implemented | App state. |

## Notifications

| Integration point | Claude Code | Cursor | Codex | OpenCode | Notes |
|---|---|---|---|---|---|
| BEL handling | Implemented | Implemented | Implemented | Implemented | Shared terminal parser path. |
| OSC 777 handling | Implemented | Implemented | Implemented | Implemented | Shared `ESC]777;notify;title;body BEL` handler. |
| Native hook attention | Implemented | Partial | Missing | Missing | Claude `Notification` hook is refreshed for existing panes when toggled. Cursor `stop` hook is installed, but toggling attention does not refresh existing Cursor providers. |
| Sidebar and pane/tab indicators | Partial | Partial | Partial | Partial | Delivery exists once callbacks are wired; see lifecycle gaps below. |
| macOS banners | Partial | Partial | Partial | Partial | Uses the same callback path as sidebar delivery. |
| Pending-notification persistence | Implemented | Implemented | Implemented | Implemented | In-app entries survive restart through `sessions.json`; banners are not replayed. |
| PR merged notifications | Partial | Partial | Partial | Partial | Status monitors subscribe to shared PR tracking; callback rewiring gaps also apply here. |

## Known Gaps

- New panes call `wireTerminalBellForNotifications` while they are still loading, before terminal controllers and status monitors exist. `completeSetup` does not wire them afterward.
- Restart, quick refresh, refresh-with-settings, and shell replacement create new controllers or monitors without rewiring notification callbacks.
- Cursor quick refresh rebuilds the environment snapshot without restoring `AGENT_SESSION_MANAGER_PANE_ID`, so Cursor hook output is no longer keyed to that pane.
- Cursor attention-toggle changes do not refresh existing Cursor providers. Claude has `refreshClaudeIntegrationFromSettings`; Cursor has no equivalent.
- OpenCode does not populate the `version` chip.
- OpenCode session status is partial: the provider emits `idle` and `busy`, but never `retry`.

## Harness Guides

Individual CLI flag catalogs remain in the harness-specific guides:

- [Claude Code pane options and shared pane flow](panes.md)
- [Cursor CLI support](cursor-cli.md)
- [Codex CLI support](codex-cli.md)
- [OpenCode CLI support](opencode-cli.md)

