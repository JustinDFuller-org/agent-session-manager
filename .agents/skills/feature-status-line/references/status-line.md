# Status Line

Agent Session Manager shows a configurable status bar at the bottom of each terminal pane. The bar is composed of rows of facts; each fact displays one fact about the running session.

## Item Catalog

| ID | Label | Availability | Source |
|----|-------|-------------|--------|
| `agentName` | Agent | Claude only | Claude hook JSON `agent.name` |
| `context` | Context % | Claude only | Claude hook JSON `context_window.used_percentage` |
| `contextRemaining` | Context Remaining | Claude only | Claude hook JSON `context_window.remaining_percentage` |
| `cost` | Cost | Claude only | Claude hook JSON `cost.total_cost_usd` |
| `duration` | Duration | All | App-computed from process start time |
| `effort` | Effort | Claude only | Claude hook JSON `effort.level` |
| `exceeds200k` | Exceeds 200k | Claude only | Claude hook JSON `exceeds_200k_tokens` |
| `inputTokens` | Input Tokens | Claude only | Claude hook JSON |
| `linesAdded` | Lines Added | All | `git diff --shortstat HEAD` (polled every 15s) |
| `linesRemoved` | Lines Removed | All | `git diff --shortstat HEAD` (polled every 15s) |
| `model` | Model | All | Claude hook JSON / Cursor hook |
| `outputStyle` | Output Style | Claude only | Claude hook JSON `output_style.name` |
| `outputTokens` | Output Tokens | Claude only | Claude hook JSON |
| `pr` | PR | All | GitHub CLI (`gh pr view`) via PRTrackingCoordinator |
| `profileName` | Profile | All | App state (selected profile) |
| `rate5h` | 5h Rate | Claude only | Claude hook JSON `rate_limits.five_hour` |
| `rate5hReset` | 5h Resets At | Claude only | Claude hook JSON `rate_limits.five_hour.resets_at` |
| `rate7d` | 7d Rate | Claude only | Claude hook JSON `rate_limits.seven_day` |
| `rate7dReset` | 7d Resets At | Claude only | Claude hook JSON `rate_limits.seven_day.resets_at` |
| `sessionName` | Session Name | Claude only | Claude hook JSON `session_name` |
| `thinking` | Thinking | Claude only | Claude hook JSON `thinking.enabled` |
| `version` | Version | All | CLI `--version` flag |
| `vimMode` | Vim Mode | Claude only | Claude hook JSON `vim.mode` |
| `worktree` | Worktree | All | App-computed from pane working directory; renders as `name • branch` |

## Invariants

### I1. Worktree name is the pane's working directory

The `worktree` fact always shows `URL(filePath: workingDirectory).lastPathComponent`. The app owns this fact; it does not rely on what a CLI reports. If the CLI sends a different name, the app logs a `statusline.worktree.name_mismatch` trace event and uses its own value.

**Authoritative source**: `StatusLineMonitor.applyI1Enforcement(to:)`, called on every Claude JSON decode.

### I2. Each fact is shown once

The old `gitWorktree` item duplicated what `worktree` already shows. It has been removed from the catalog. Saved configurations containing `gitWorktree` rows are silently migrated on first decode, emitting `statusline.migration.gitworktree_dropped`.

### I3. Lines added/removed means vs HEAD

`linesAdded` and `linesRemoved` always reflect `git diff --shortstat HEAD`, polled every 15 seconds by `GitDiffStats.compute(in:)`. This is consistent for all CLIs:

- **ToolAgnosticDataProvider, CursorDataProvider**: call `GitDiffStats.compute` in `refreshNow()` and populate `Cost.totalLinesAdded/Removed`.
- **StatusLineMonitor (Claude)**: maintains a 15s `gitDiffTimer` whose results are cached in `cachedGitStats`. After decoding Claude JSON, `applyI3Enforcement(to:)` replaces the JSON values with the cached git values and logs `statusline.lines.source_mismatch` on disagreement.

### Empty state

The fact row renders as soon as the user has configured at least one row. Missing fields show `—` until the harness emits its first status payload. The `currentData != nil` gate was removed from both `StatusLineView.body` and `PaneView.statusLine`; `StatusLineView` now renders whenever `nonEmptyRows` is non-empty, regardless of whether hook data has arrived.

### I4. Add Item picker is alphabetical

Items in the Add Item dropdown are sorted by label using `localizedStandardCompare`. The internal `itemOrder` array (which governs default row construction) is unchanged.

**Authoritative source**: `StatusLineConfigLayoutEditor.unusedItemsEligibleForAddition()`.

### I6. currentData always reflects the most recent status payload on disk (Liveness)

`currentData` must stay in sync with the file at `filePath`. The vnode `DispatchSource` fires on `.write`/`.extend` and, when Claude Code replaces the inode (atomic temp-write+rename), on `.delete`/`.rename`/`.revoke`; the latter case triggers a fd+source reopen so the watcher tracks the current inode. As a redundant enforcer, the 15s git-diff timer compares the file's `mtime` to `lastAppliedModificationDate`; on divergence it re-applies and records `statusline.payload.stale_recovered`.

**Authoritative source**: `StatusLineMonitor.startStatusWatcher()`, `checkPayloadFreshness()`.

### I7. Every status write either applies or records a decode failure (Integrity)

Errors during payload processing are never silently dropped. `applyLatestPayload(reason:)` uses `do/catch` for both the file read and JSON decode. On failure it records `statusline.payload.decode_failed` and leaves `currentData` intact. On success it records `statusline.payload.applied`. Empty reads are skipped without recording or clobbering state. `ContextWindow` integer fields are decoded via a tolerant Int-or-Double path so floating-point representations (e.g., `14.000000000000002`) degrade to the truncated `Int` rather than failing the whole payload.

**Authoritative source**: `StatusLineMonitor.applyLatestPayload(reason:)`, `StatusLineData.ContextWindow.flexInt`.

**View corollary**: missing numeric fields render as `—`, never as `0`/`$0.0000`, so a frozen or early payload shows visibly-missing data rather than masquerading as real zeros.

### I5. Worktree fact is a single item (name + branch)

The `worktree` fact renders as `name • branch` when both values are available, or just `name` when branch is absent (computed by `StatusLineData.Worktree.factText`). The old `worktreeBranch` item has been removed from the catalog. Saved configurations containing `worktreeBranch` rows are migrated on first decode: if the row does not already have a `worktree` item, `worktreeBranch` is replaced by `worktree`; otherwise it is dropped. The migration emits `statusline.migration.worktreebranch_merged`.

## Defaults

`StatusLineConfig()` (catalog default): single row — `model`, `worktree`, `cost`, `context`. Used when no saved config exists and when the onboarding wizard is skipped from the welcome step.

`StatusLineConfig.wizardDefault()` (wizard default): three rows — Row 1: `pr`/`profileName`/`model`; Row 2: `context`/`contextRemaining`/`inputTokens`/`outputTokens`; Row 3: `worktree`/`linesAdded`/`linesRemoved`. Used exclusively by the onboarding wizard status line step and its Reset button.

## Key Files

| File | Role |
|------|------|
| `Sources/.../Models/StatusLineConfig.swift` | Item catalog, availability, order, decoder migration, `wizardDefault()` factory |
| `Sources/.../Controllers/GitDiffStats.swift` | `git diff --shortstat HEAD` runner and parser |
| `Sources/.../Controllers/StatusLineMonitor.swift` | I1/I3 enforcement for Claude panes, git diff polling |
| `Sources/.../Controllers/ToolAgnosticDataProvider.swift` | Git stats for non-Claude panes |
| `Sources/.../Controllers/CursorDataProvider.swift` | Git stats for Cursor panes |
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
| `statusline.migration.worktreebranch_merged` | `row_index`, `position`, `substituted` | I5 migration |
| `statusline.payload.applied` | `pane.name`, `reason`, `cost_usd`, `used_pct`, `inode` | I7: every successful payload apply |
| `statusline.payload.decode_failed` | `pane.name`, `reason`, `error`, `byte_count`, `payload_prefix` | I7: read or JSON decode failure |
| `statusline.payload.stale_recovered` | `pane.name`, `file_mtime`, `stale_age_seconds` | I6: vnode watcher missed a write; timer recovered |
