# Status Line

Agent Session Manager shows a configurable status bar at the bottom of each terminal pane. The bar is composed of rows of chips; each chip displays one fact about the running session.

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
| `sessionStatus` | Status | OpenCode only | OpenCode DB (idle/busy/retry) |
| `thinking` | Thinking | Claude only | Claude hook JSON `thinking.enabled` |
| `version` | Version | All | CLI `--version` flag |
| `vimMode` | Vim Mode | Claude only | Claude hook JSON `vim.mode` |
| `worktree` | Worktree | All | App-computed from pane working directory |
| `worktreeBranch` | Worktree Branch | All | `git branch --show-current` |

## Invariants

### I1. Worktree name is the pane's working directory

The `worktree` chip always shows `URL(filePath: workingDirectory).lastPathComponent`. The app owns this fact; it does not rely on what a CLI reports. If the CLI sends a different name, the app logs a `statusline.worktree.name_mismatch` trace event and uses its own value.

**Authoritative source**: `StatusLineMonitor.applyI1Enforcement(to:)`, called on every Claude JSON decode.

### I2. Each fact has exactly one chip

The old `gitWorktree` item duplicated what `worktree` already shows. It has been removed from the catalog. Saved configurations containing `gitWorktree` rows are silently migrated on first decode, emitting `statusline.migration.gitworktree_dropped`.

### I3. Lines added/removed means vs HEAD

`linesAdded` and `linesRemoved` always reflect `git diff --shortstat HEAD`, polled every 15 seconds by `GitDiffStats.compute(in:)`. This is consistent for all CLIs:

- **ToolAgnosticDataProvider, CursorDataProvider, OpenCodeDataProvider**: call `GitDiffStats.compute` in `refreshNow()` and populate `Cost.totalLinesAdded/Removed`.
- **StatusLineMonitor (Claude)**: maintains a 15s `gitDiffTimer` whose results are cached in `cachedGitStats`. After decoding Claude JSON, `applyI3Enforcement(to:)` replaces the JSON values with the cached git values and logs `statusline.lines.source_mismatch` on disagreement.

### Empty state

The chip row renders as soon as the user has configured at least one row. Missing fields show `—` until the CLI emits its first status payload. The `currentData != nil` gate was removed from both `StatusLineView.body` and `PaneView.statusLine`; `StatusLineView` now renders whenever `nonEmptyRows` is non-empty, regardless of whether hook data has arrived.

### I4. Add Item picker is alphabetical

Items in the Add Item dropdown are sorted by label using `localizedStandardCompare`. The internal `itemOrder` array (which governs default row construction) is unchanged.

**Authoritative source**: `StatusLineConfigLayoutEditor.unusedItemsEligibleForAddition()`.

## Key Files

| File | Role |
|------|------|
| `Sources/.../Models/StatusLineConfig.swift` | Item catalog, availability, order, decoder migration |
| `Sources/.../Controllers/GitDiffStats.swift` | `git diff --shortstat HEAD` runner and parser |
| `Sources/.../Controllers/StatusLineMonitor.swift` | I1/I3 enforcement for Claude panes, git diff polling |
| `Sources/.../Controllers/ToolAgnosticDataProvider.swift` | Git stats for non-Claude/non-OpenCode panes |
| `Sources/.../Controllers/CursorDataProvider.swift` | Git stats for Cursor panes |
| `Sources/.../Controllers/OpenCodeDataProvider.swift` | Git stats for OpenCode panes |
| `Sources/.../Views/StatusLineView.swift` | Chip rendering |
| `Sources/.../Views/StatusLineSettingsViews.swift` | Settings UI and alphabetical picker |
| `Tests/GitDiffStatsTests.swift` | Parser unit tests |
| `Tests/StatusLineMonitorInvariantTests.swift` | I1, I2, I3 invariant tests |

## Trace Events

| Event | Attributes | Source |
|-------|-----------|--------|
| `statusline.worktree.name_mismatch` | `pane.name`, `field`, `computed`, `reported` | I1 violation |
| `statusline.lines.source_mismatch` | `pane.name`, `computed_added`, `reported_added`, `computed_removed`, `reported_removed` | I3 violation |
| `statusline.migration.gitworktree_dropped` | `row_index`, `position` | I2 migration |
