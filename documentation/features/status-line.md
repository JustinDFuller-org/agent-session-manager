# Status Line

Agent Session Manager shows a configurable status bar at the bottom of each terminal pane. The bar is composed of rows of chips; each chip displays one fact about the running session.

The catalog controls which chips can be selected for a harness. Catalog availability does not guarantee that a provider currently populates the field: unavailable provider data renders as `—`. For example, Codex can select `model` but does not populate it, and OpenCode can select `version` but does not populate it. See [agent-harness-feature-matrix.md](agent-harness-feature-matrix.md) for the per-harness audit.

## Item Catalog

| ID | Label | Availability | Source |
|----|-------|-------------|--------|
| `agentName` | Agent | Claude only | Claude hook JSON `agent.name` |
| `context` | Context % | Claude only | Claude hook JSON `context_window.used_percentage` |
| `contextRemaining` | Context Remaining | Claude only | Claude hook JSON `context_window.remaining_percentage` |
| `cost` | Cost | Claude + OpenCode | Claude hook JSON `cost.total_cost_usd` / OpenCode DB |
| `duration` | Duration | All | App-computed from process start time |
| `effort` | Effort | Claude only | Claude hook JSON `effort.level` |
| `exceeds200k` | Exceeds 200k | Claude only | Claude hook JSON `exceeds_200k_tokens` |
| `inputTokens` | Input Tokens | Claude + OpenCode | Claude hook JSON / OpenCode DB |
| `linesAdded` | Lines Added | All | `git diff --shortstat HEAD` (polled every 15s) |
| `linesRemoved` | Lines Removed | All | `git diff --shortstat HEAD` (polled every 15s) |
| `model` | Model | All | Claude hook JSON / OpenCode DB / Cursor hook |
| `openCodeMode` | Mode | OpenCode only | OpenCode DB `mode` field |
| `outputStyle` | Output Style | Claude only | Claude hook JSON `output_style.name` |
| `outputTokens` | Output Tokens | Claude + OpenCode | Claude hook JSON / OpenCode DB |
| `pr` | PR | All | GitHub CLI (`gh pr view`) via PRTrackingCoordinator |
| `profileName` | Profile | All | App state (selected profile) |
| `rate5h` | 5h Rate | Claude only | Claude hook JSON `rate_limits.five_hour` |
| `rate5hReset` | 5h Resets At | Claude only | Claude hook JSON `rate_limits.five_hour.resets_at` |
| `rate7d` | 7d Rate | Claude only | Claude hook JSON `rate_limits.seven_day` |
| `rate7dReset` | 7d Resets At | Claude only | Claude hook JSON `rate_limits.seven_day.resets_at` |
| `sessionName` | Session Name | Claude only | Claude hook JSON `session_name` |
| `sessionStatus` | Status | OpenCode only | OpenCode DB (`idle` / `busy`; renderer supports `retry`, but provider does not emit it) |
| `thinking` | Thinking | Claude only | Claude hook JSON `thinking.enabled` |
| `version` | Version | All | Claude hook JSON / Cursor and Codex CLI `--version`; OpenCode currently unpopulated |
| `vimMode` | Vim Mode | Claude only | Claude hook JSON `vim.mode` |
| `worktree` | Worktree | All | App-computed from pane working directory; renders as `name • branch` |

## Invariants

The status line enforces five invariants that guarantee consistent values regardless of which CLI is in use.

### I1. Worktree name is the pane's working directory

The `worktree` chip always shows `URL(filePath: workingDirectory).lastPathComponent`. The app owns this fact; it does not rely on what a CLI reports. If the CLI sends a different name, the app logs a mismatch and uses its own value.

### I2. Each fact has exactly one chip

The old `gitWorktree` item duplicated what `worktree` already shows. It has been removed. Saved configurations containing `gitWorktree` rows are silently migrated on first load.

### I3. Lines added/removed means vs HEAD

`linesAdded` and `linesRemoved` always reflect `git diff --shortstat HEAD`, polled every 15 seconds in the pane's working directory. This is consistent for all CLIs. For Claude panes, if the Claude hook JSON disagrees, the app logs a mismatch and uses the git-computed value.

### I4. Add Item picker is alphabetical

Items in the Add Item dropdown are sorted by label using `localizedStandardCompare`. The internal `itemOrder` array (which governs default row construction) is unchanged.

### I5. Worktree chip is a single fact (name + branch)

The `worktree` chip renders as `name • branch` when both values are available, or just `name` when branch is absent. The old `worktreeBranch` item, which duplicated the branch half of this fact, has been removed. Saved configurations containing `worktreeBranch` rows are migrated on first load: if the row does not already have a `worktree` item, `worktreeBranch` is replaced by `worktree`; otherwise it is dropped.

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
3. Click **Add Item** inside any row to see available items (filtered by the CLI type of the current pane, alphabetically sorted)
4. Click the minus icon to remove an item
5. Use the up/down arrows to reorder rows

## Invariant Violation Trace Events

When an invariant is violated, the app records a trace event (see [tracing.md](tracing.md)) and uses the authoritative value. These events are the primary signal that an upstream contract has changed.

| Event | When emitted |
|-------|-------------|
| `statusline.worktree.name_mismatch` | Claude JSON `worktree.name` or `workspace.git_worktree` disagrees with the app's computed worktree name (I1) |
| `statusline.lines.source_mismatch` | Claude JSON `cost.total_lines_added`/`total_lines_removed` disagrees with cached `git diff --shortstat HEAD` (I3) |
| `statusline.migration.gitworktree_dropped` | A saved config row contained `gitWorktree`; it was removed (I2) |
| `statusline.migration.worktreebranch_merged` | A saved config row contained `worktreeBranch`; it was replaced by `worktree` (`substituted=true`) or dropped (`substituted=false`) (I5) |
