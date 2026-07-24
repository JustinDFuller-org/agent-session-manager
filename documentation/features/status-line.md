# Status Line

Agent Session Manager shows a configurable status bar at the bottom of each terminal pane. The bar is composed of rows of facts; each fact displays one fact about the running session.

The catalog controls which chips can be selected for a harness. Each fact declares an owner (`app`, `harness`, or `merged`), supported harnesses, and whether missing data should render as pending or unsupported. Unsupported facts are omitted for that pane; supported facts with no current value render `—`. See [agent-harness-feature-matrix.md](agent-harness-feature-matrix.md) for the per-harness audit.

Facts show their SF Symbol and label by default. Explicit `labelOnly` and `symbolOnly` configurations are preserved; older saved configurations that omitted the style migrate to the symbol-and-label default.

## Item Catalog

| ID | Label | Availability | Source |
|----|-------|-------------|--------|
| `agentName` | Agent | Claude only | Claude hook JSON `agent.name` |
| `context` | Context % | Claude, Codex | Claude hook JSON; Codex 0.136.x rollout `last_token_usage.total_tokens / model_context_window` |
| `contextRemaining` | Context Remaining | Claude, Codex | Claude hook JSON; Codex 0.136.x rollout context percentage remainder |
| `cost` | Cost | Claude only | Claude hook JSON `cost.total_cost_usd` |
| `duration` | Duration | All | App-computed from process start time |
| `effort` | Effort | Claude only | Claude hook JSON `effort.level` |
| `exceeds200k` | Exceeds 200k | Claude only | Claude hook JSON `exceeds_200k_tokens` |
| `inputTokens` | Input Tokens | Claude, Codex | Claude hook JSON; Codex 0.136.x rollout `total_token_usage.input_tokens` |
| `linesAdded` | Lines Added | All | `git diff --shortstat HEAD` (polled every 15s) |
| `linesRemoved` | Lines Removed | All | `git diff --shortstat HEAD` (polled every 15s) |
| `model` | Model | All | Claude hook JSON; Cursor hook; Codex state DB/rollout metadata |
| `outputStyle` | Output Style | Claude only | Claude hook JSON `output_style.name` |
| `outputTokens` | Output Tokens | Claude, Codex | Claude hook JSON; Codex 0.136.x rollout `total_token_usage.output_tokens` |
| `pr` | PR | All | GitHub CLI (`gh pr view`) via PRTrackingCoordinator |
| `profileName` | Profile | All | App state (selected profile) |
| `rate5h` | 5h Rate | Claude, Codex | Claude hook JSON; Codex 300-minute primary rate window |
| `rate5hReset` | 5h Resets At | Claude, Codex | Claude hook JSON; Codex 300-minute primary rate window |
| `rate7d` | 7d Rate | Claude, Codex | Claude hook JSON; Codex 10,080-minute secondary rate window |
| `rate7dReset` | 7d Resets At | Claude, Codex | Claude hook JSON; Codex 10,080-minute secondary rate window |
| `sessionName` | Session Name | Claude only | Claude hook JSON `session_name` |
| `thinking` | Thinking | Claude only | Claude hook JSON `thinking.enabled` |
| `version` | Version | All | Claude hook JSON / Cursor and Codex CLI `--version` |
| `vimMode` | Vim Mode | Claude only | Claude hook JSON `vim.mode` |
| `worktree` | Worktree | All | App-computed from pane working directory; renders as `name • branch` |

## Providers

`StatusLineMonitor` coordinates one provider path per pane and exposes merged `StatusLineData` to `StatusLineView`.

- Claude panes use the Claude `statusLine` hook payload and preserve the existing I1/I3 enforcement.
- Cursor panes combine app-owned baseline facts with Cursor hook model data.
- Codex panes combine app-owned baseline facts with a hook-bound Codex session. Codex lifecycle hooks write the actual `session_id`, `cwd`, model, and `transcript_path` for the pane. The provider starts baseline polling immediately and keeps watching the pane-scoped hook record path until the first valid pane/tab record arrives, even if that happens after the startup window. Once bound, it pins the session id/transcript path for the pane lifetime, tails only that transcript, and uses `~/.codex/state_5.sqlite` only as optional enrichment by exact session id or exact transcript/rollout path. It never selects by latest same-working-directory row.

Codex rollout parsing is intentionally bounded and content-avoiding. It accepts `session_meta.payload`, `turn_context`, and token-count `event_msg.payload.info` records, maps model/version/token/context/rate facts, and ignores message-content records. Startup catch-up reads only the latest 200 complete rollout lines and buffers partial JSONL writes until the newline arrives. Cost remains unsupported for Codex until Codex exposes a stable source.

## Invariants

The status line enforces five invariants that guarantee consistent values regardless of which CLI is in use.

### I1. Worktree name is the pane's working directory

The `worktree` fact always shows `URL(filePath: workingDirectory).lastPathComponent`. The app owns this fact; it does not rely on what a CLI reports. If the CLI sends a different name, the app logs a mismatch and uses its own value.

### I2. Each fact is shown once

The old `gitWorktree` item duplicated what `worktree` already shows. It has been removed. Saved configurations containing `gitWorktree` rows are silently migrated on first load.

### I3. Lines added/removed means vs HEAD

`linesAdded` and `linesRemoved` always reflect `git diff --shortstat HEAD`, polled every 15 seconds in the pane's working directory. This is consistent for all CLIs. For Claude panes, if the Claude hook JSON disagrees, the app logs a mismatch and uses the git-computed value.

### I4. Add Item picker is alphabetical

Items in the Add Item dropdown are sorted by label using `localizedStandardCompare`. The internal `itemOrder` array (which governs default row construction) is unchanged.

### I5. Worktree fact is a single item (name + branch)

The `worktree` fact renders as `name • branch` when both values are available, or just `name` when branch is absent. The old `worktreeBranch` item, which duplicated the branch half of this fact, has been removed. Saved configurations containing `worktreeBranch` rows are migrated on first load: if the row does not already have a `worktree` item, `worktreeBranch` is replaced by `worktree`; otherwise it is dropped.

## Onboarding

On first launch the setup wizard presents a **Status Line** step (step 4 of 4) that pre-fills the wizard default layout:

- Row 1: `pr`, `profileName`, `model`
- Row 2: `context`, `contextRemaining`, `inputTokens`, `outputTokens`
- Row 3: `worktree`, `linesAdded`, `linesRemoved`

**Save** persists this config to `statusline-settings.json`. **Skip** writes an empty `rows` array, which renders no status bar. When the draft equals `wizardDefault()`, a **Clear** button empties all rows; once the layout diverges, the button becomes **Reset to Default** and restores the three-row spec.

The wizard default (`StatusLineConfig.wizardDefault()`) is distinct from the catalog default (`StatusLineConfig()` — single row: model, worktree, cost, context). The catalog default is unchanged and remains the fallback for code paths that skip the wizard (e.g. the welcome-step **Skip** button).

See [setup-wizard.md](setup-wizard.md) for the full wizard flow.

## Configuring Rows

1. Open **Settings → Status Line**
2. Use **+ Add Row** to add a new row
3. Click **Add Item** inside any row to see available items (filtered by the harness of the current pane, alphabetically sorted)
4. Click the minus icon to remove an item
5. Use the up/down arrows to reorder rows

## Invariant Violations

When an invariant is violated, the app reports it through `InvariantReporter`, records the preserved trace event (see [tracing.md](tracing.md)), and uses the authoritative value. With Debug mode enabled, occurrences are also appended to `invariants/invariants.jsonl` and shown in the Invariant Dashboard.

| Invariant ID | Preserved trace event | When emitted |
|-------|-------------|---|
| `statusline.worktree.name` | `statusline.worktree.name_mismatch` | Claude JSON `worktree.name` or `workspace.git_worktree` disagrees with the app's computed worktree name (I1) |
| `statusline.lines.source` | `statusline.lines.source_mismatch` | Claude JSON `cost.total_lines_added`/`total_lines_removed` disagrees with cached `git diff --shortstat HEAD` (I3) |

Migration-only events remain trace events:

| Event | When emitted |
|-------|-------------|
| `statusline.migration.gitworktree_dropped` | A saved config row contained `gitWorktree`; it was removed (I2) |
| `statusline.migration.worktreebranch_merged` | A saved config row contained `worktreeBranch`; it was replaced by `worktree` (`substituted=true`) or dropped (`substituted=false`) (I5) |
| `statusline.provider.started` | A provider starts for a pane |
| `statusline.provider.stopped` | A provider stops for a pane |
| `statusline.provider.update_applied` | A provider snapshot is applied to the pane monitor |
| `statusline.provider.update_failed` | Reserved for provider snapshot failures |
| `statusline.codex.hook_waiting` | Codex provider is still waiting for a hook record; includes retry attempt, late-binding state, and hook availability |
| `statusline.codex.hook_bound` | Codex hook record bound the pane to a session; includes hook availability, event name, session id prefix, retry attempt, late-binding state, and transcript availability |
| `statusline.codex.hook_record_ignored` | Codex hook record was present but rejected, usually because the pane/tab ids did not match |
| `statusline.codex.sqlite_enrichment` | Optional Codex SQLite enrichment result; includes exact-match outcome, retry attempt, selected session id prefix, and rollout path match |
| `statusline.codex.selection_failed` | Codex hook binding failed or was still waiting; retryable startup failures include retry reason/attempt |
| `statusline.codex.tailer_started` | Codex transcript/rollout tailer starts for the hook-bound session |
| `statusline.codex.tailer_read` | Codex rollout tailer reads a bounded batch; includes line/update counts and whether the read was startup catch-up |
| `statusline.codex.parsed_update` | Codex rollout parsing produced a supported update; records model/token/context/rate-limit field presence |
| `statusline.codex.state_unavailable` | Reserved legacy event for Codex state DB failures |
| `statusline.codex.session_ambiguous` | Reserved legacy event for ambiguous Codex state rows |
| `statusline.codex.rollout_unavailable` | Reserved legacy event for missing Codex rollout paths |
| `statusline.codex.schema_unsupported` | The detected Codex version has no rollout adapter |
