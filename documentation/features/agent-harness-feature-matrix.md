# Agent Harness Feature Matrix

This is the canonical, code-observed audit of Agent Session Manager integration points for Claude Code, Cursor, and Codex as of **July 3, 2026**. It describes the app implementation, not upstream CLI feasibility. The internal `.shell` pane type is excluded.

## Legend

| Status | Meaning |
|---|---|
| **Implemented** | Wired end to end in Agent Session Manager |
| **Partial** | Present, but with a known limitation or lifecycle gap |
| **Missing** | Not implemented in Agent Session Manager |
| **N/A** | Intentionally not applicable to that harness |

## Product Surface

| Surface | Claude Code | Cursor | Codex | Notes |
|---|---|---|---|---|
| Tool detection | Implemented | Implemented | Implemented | `CLIToolDetector` probes `claude`, `agent`, and `codex` in the selected interactive shell. |
| Tool activation | Implemented | Implemented | Implemented | Settings persist active harnesses; only active harnesses appear in New Pane. |
| Launch command | Implemented | Implemented | Implemented | Launches `claude --settings ...`, `agent`, or `codex` in the resolved checkout. |
| Configurable CLI options | Implemented | Implemented | Implemented | Each harness has a separate catalog. See the harness-specific CLI guides linked below. |
| Configurable environment variables | Implemented | N/A | N/A | The user-facing environment-variable catalog is Claude-specific. Cursor also receives the internal `AGENT_SESSION_MANAGER_PANE_ID`. |
| Profiles: CLI options | Implemented | Implemented | Implemented | Profiles store a harness type and harness-specific CLI options. |
| Profiles: environment variables | Implemented | N/A | N/A | Profile environment variables are Claude-specific. |
| Worktree resolution | Implemented | Implemented | Implemented | New Pane passes every harness through `Tab.resolveOrAttachWorktree`. |
| Loading overlay during worktree setup | Implemented | Implemented | Implemented | `addPaneWithLoadingState` precedes async Git setup for every harness. |
| External worktree attachment | Implemented | Implemented | Implemented | Existing paths from `git worktree list --porcelain` can be reused. |
| Managed worktree cleanup | Implemented | Implemented | Implemented | Cleanup is based on pane worktree ownership, not harness type. |
| Session restore | Implemented | Implemented | Implemented | Persisted resolved checkout directories are restored for every harness when they still exist. |
| Continue on app restart | Implemented | N/A | N/A | Automatic restore-time `--continue` injection is Claude-only. |
| Auto session names | Implemented | N/A | N/A | Automatic `--name '<tab>/<pane>'` injection is Claude-only. |
| Restart existing process | Implemented | Implemented | Implemented | Controller replacement preserves the existing monitor and callback wiring. |
| Quick refresh and continue | Implemented | Implemented | Implemented | Monitor replacement goes through `Pane.installStatusLineMonitor`, which reattaches callbacks. Cursor quick refresh preserves `AGENT_SESSION_MANAGER_PANE_ID`. |
| Refresh with new settings | Implemented | Implemented | Implemented | Monitor/controller replacement goes through pane install methods that rewire callbacks. |
| Rich status provider | Implemented | Partial | Partial | Claude uses `statusLine`; Cursor adds hook model data; Codex adds version-gated SQLite/rollout data for 0.136.x. |
| Shared baseline status | Implemented | Implemented | Implemented | Worktree, branch, duration, lines changed, PR, and profile chips are app-owned where data is available. Cursor and Codex fetch versions. |
| Native attention integration | Implemented | Partial | Missing | Claude uses `Notification` (broadened to `permission_prompt\|elicitation_dialog\|idle_prompt\|agent_needs_input`) plus `SubagentStop`/`PreToolUse` background-agent gating to suppress false "finished" `Stop` notifications; Cursor uses `stop`, but setting changes do not refresh existing panes. |
| Shared terminal attention | Implemented | Implemented | Implemented | BEL and OSC 777 flow through `TerminalController`. |
| Notification sidebar and banners | Partial | Partial | Partial | Delivery exists, but new-pane and controller-replacement lifecycle gaps can prevent callbacks from being attached. |
| Notification persistence | Implemented | Implemented | Implemented | Pending in-app notifications are stored in `sessions.json`. |
| GitHub PR tracking | Implemented | Implemented | Implemented | `PRTrackingCoordinator` is harness-independent. |
| PR merged notifications | Partial | Partial | Partial | Provider delivery exists for every monitor, but notification callback rewiring has the lifecycle gaps above. |
| Observability and trace dashboard | Implemented | Implemented | Implemented | Trace recording and dashboard grouping are app-level features. |

## Status Chips

The catalog controls whether a chip can be selected for a harness. A selectable chip can still render `—` when its provider does not populate the field.

| Chip ID | Claude Code | Cursor | Codex | Source or gap |
|---|---|---|---|---|
| `model` | Implemented | Implemented | Partial | Claude hook JSON; Cursor `afterAgentResponse` hook; Codex SQLite/rollout metadata for supported versions. |
| `worktree` | Implemented | Implemented | Implemented | App-owned checkout directory plus Git branch. |
| `cost` | Implemented | N/A | N/A | Claude hook JSON. |
| `context` | Implemented | N/A | Partial | Claude hook JSON percentage; Codex rollout token count for supported versions. |
| `effort` | Implemented | N/A | N/A | Claude hook JSON. |
| `thinking` | Implemented | N/A | N/A | Claude hook JSON. |
| `vimMode` | Implemented | N/A | N/A | Claude hook JSON. |
| `agentName` | Implemented | N/A | N/A | Claude hook JSON. |
| `sessionName` | Implemented | N/A | N/A | Claude hook JSON. |
| `linesAdded` | Implemented | Implemented | Implemented | App-owned `git diff --shortstat HEAD`. |
| `linesRemoved` | Implemented | Implemented | Implemented | App-owned `git diff --shortstat HEAD`. |
| `duration` | Implemented | Implemented | Implemented | App-owned process duration. |
| `contextRemaining` | Implemented | N/A | Partial | Claude hook JSON percentage; Codex rollout token count for supported versions. |
| `inputTokens` | Implemented | N/A | Partial | Claude hook JSON; Codex rollout token count for supported versions. |
| `outputTokens` | Implemented | N/A | Partial | Claude hook JSON; Codex rollout token count for supported versions. |
| `rate5h` | Implemented | N/A | Partial | Claude hook JSON; Codex primary 300-minute rate window for supported versions. |
| `rate7d` | Implemented | N/A | Partial | Claude hook JSON; Codex secondary 10,080-minute rate window for supported versions. |
| `rate5hReset` | Implemented | N/A | Partial | Claude hook JSON; Codex primary 300-minute rate window for supported versions. |
| `rate7dReset` | Implemented | N/A | Partial | Claude hook JSON; Codex secondary 10,080-minute rate window for supported versions. |
| `version` | Implemented | Implemented | Implemented | Claude hook JSON; Cursor and Codex run `<command> --version`. |
| `outputStyle` | Implemented | N/A | N/A | Claude hook JSON. |
| `exceeds200k` | Implemented | N/A | N/A | Claude hook JSON. |
| `pr` | Implemented | Implemented | Implemented | App-level GitHub CLI polling. |
| `profileName` | Implemented | Implemented | Implemented | App state. |

## Notifications

| Integration point | Claude Code | Cursor | Codex | Notes |
|---|---|---|---|---|
| BEL handling | Implemented | Implemented | Implemented | Shared terminal parser path. |
| OSC 777 handling | Implemented | Implemented | Implemented | Shared `ESC]777;notify;title;body BEL` handler. |
| Native hook attention | Implemented | Partial | Missing | Claude `Notification` hook (`permission_prompt`, `elicitation_dialog`, `idle_prompt`, `agent_needs_input`) is refreshed for existing panes when toggled. Cursor `stop` hook is installed, but toggling attention does not refresh existing Cursor providers. |
| Background-agent completion gating (`SubagentStop`) | Implemented | N/A | N/A | Claude registers `SubagentStop` and a `PreToolUse` matcher for `Task\|Agent`; the outstanding-agent count derived from those hooks suppresses the false "Claude finished" `Stop` notification while background agents (e.g. plan-mode Explore agents) are still running. |
| Sidebar and pane/tab indicators | Partial | Partial | Partial | Delivery exists once callbacks are wired; see lifecycle gaps below. |
| macOS banners | Partial | Partial | Partial | Uses the same callback path as sidebar delivery. |
| Pending-notification persistence | Implemented | Implemented | Implemented | In-app entries survive restart through `sessions.json`; banners are not replayed. |
| PR merged notifications | Partial | Partial | Partial | Status monitors subscribe to shared PR tracking; callback rewiring gaps also apply here. |

## Known Gaps

- Cursor attention-toggle changes do not refresh existing Cursor providers. Claude has `refreshClaudeIntegrationFromSettings`; Cursor has no equivalent.
- Codex rollout parsing is currently supported only for Codex `0.136.x`; unknown versions degrade to baseline/state DB facts.

## Harness Guides

Individual CLI flag catalogs remain in the harness-specific guides:

- [Claude Code pane options and shared pane flow]({{ '/documentation/features/panes/' | relative_url }})
- [Cursor CLI support]({{ '/documentation/features/cursor-cli/' | relative_url }})
- [Codex CLI support]({{ '/documentation/features/codex-cli/' | relative_url }})
