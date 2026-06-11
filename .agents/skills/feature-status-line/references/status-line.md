# Status Line

Agent Session Manager shows a configurable status bar at the bottom of each terminal pane. The bar is composed of rows of facts; each fact displays one fact about the running session.

## Item Catalog

| ID | Label | Availability | Source |
|----|-------|-------------|--------|
| `agentName` | Agent | Claude only | Claude hook JSON `agent.name` |
| `context` | Context % | Claude + Codex | Claude hook JSON `context_window.used_percentage` / Codex rollout token count |
| `contextRemaining` | Context Remaining | Claude + Codex | Claude hook JSON `context_window.remaining_percentage` / Codex rollout token count |
| `cost` | Cost | Claude only | Claude hook JSON `cost.total_cost_usd` |
| `duration` | Duration | All | App-computed from process start time |
| `effort` | Effort | Claude only | Claude hook JSON `effort.level` |
| `exceeds200k` | Exceeds 200k | Claude only | Claude hook JSON `exceeds_200k_tokens` |
| `inputTokens` | Input Tokens | Claude + Codex | Claude hook JSON / Codex rollout token count |
| `linesAdded` | Lines Added | All | `git diff --shortstat HEAD` (polled every 15s) |
| `linesRemoved` | Lines Removed | All | `git diff --shortstat HEAD` (polled every 15s) |
| `model` | Model | All | Claude hook JSON / Cursor hook |
| `outputStyle` | Output Style | Claude only | Claude hook JSON `output_style.name` |
| `outputTokens` | Output Tokens | Claude + Codex | Claude hook JSON / Codex rollout token count |
| `pr` | PR | All | GitHub CLI (`gh pr view`) via PRTrackingCoordinator |
| `profileName` | Profile | All | App state (selected profile) |
| `rate5h` | 5h Rate | Claude + Codex | Claude hook JSON `rate_limits.five_hour` / Codex rollout primary rate limit |
| `rate5hReset` | 5h Resets At | Claude + Codex | Claude hook JSON `rate_limits.five_hour.resets_at` / Codex rollout primary rate limit |
| `rate7d` | 7d Rate | Claude + Codex | Claude hook JSON `rate_limits.seven_day` / Codex rollout secondary rate limit |
| `rate7dReset` | 7d Resets At | Claude + Codex | Claude hook JSON `rate_limits.seven_day.resets_at` / Codex rollout secondary rate limit |
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

## Claude statusLine Schema & Field Ownership

Claude writes a JSON file at a well-known path; the app reads it via `StatusLineMonitor`. The [official schema](https://code.claude.com/docs/en/statusline) defines which keys Claude guarantees and their types.

### Decoding strategy

`StatusLineData.CodingKeys` lists only the fields the app decodes. Fields outside that list are silently ignored. Rules for adding a field:

- **Model only what Claude guarantees.** Make a field optional (`?`) only when Claude documents it as potentially absent. Non-optional fields in nested structs must be present whenever the parent key appears.
- **Use `decodeIfPresent` for optional top-level keys.** Swift's synthesized decoder does this automatically for `T?` properties.
- **If the app owns the fact, omit `case <field>` from `CodingKeys`.** The property still exists for app-side assignment; Swift requires a default (`= nil`) so the synthesized decoder can skip it.

### Field ownership table

| Field on `StatusLineData` | Owned by | Source | Notes |
|---------------------------|----------|--------|-------|
| `model` | Claude | `model.id`, `model.display_name` | — |
| `cost` | Claude | `cost.*` | — |
| `contextWindow` | Claude | `context_window.*` | Integer fields via `flexInt` (tolerates `Double`) |
| `rateLimits` | Claude | `rate_limits.*` | — |
| `worktree` | Claude | `worktree.*` | I1 enforces the name post-decode |
| `workspace` | Claude | `workspace.*` | — |
| `effort`, `thinking`, `agent`, `outputStyle`, `vim`, `sessionName`, `version`, `exceeds200kTokens`, `sessionStatus` | Claude | Respective JSON keys | — |
| `repo` | App (`git remote get-url origin`) | `cachedRepoIdentity`, set post-decode | Claude provides repo under `workspace.repo`, not top-level; top-level `repo` is app-derived |
| `pr` | App (`PRTrackingCoordinator` via `gh`) | gh GraphQL `reviewDecision` + `PullRequest` fields | Claude's `pr` block (`number/url/review_state`) is ignored; `case pr` is absent from `CodingKeys` |

### Why `pr` is excluded from CodingKeys

Claude's documented `pr` block carries `{number, url, review_state}`. The app's `PullRequest` type (used for the `pr` status line fact) requires non-optional `title` and `state` — fields gh provides but Claude never does. Decoding Claude's `pr` into `PullRequest` threw `keyNotFound` on `title`/`state`, causing the **entire payload to fail** and the status line to freeze on any branch with an open PR.

The fix: remove `case pr` from `StatusLineData.CodingKeys` and add `= nil` as the default. Swift's synthesized decoder skips the property entirely. The gh-sourced `PullRequest` set by `PRTrackingCoordinator` is preserved across payloads by the `if let existing = currentData?.pr { enforced.pr = existing }` overwrite in `applyLatestPayload`.

Claude's `pr.review_state` (`approved|pending|changes_requested|draft`) is also intentionally unused — the app derives review state from gh's `reviewDecision` field set in `parsePRFromGraphQLNode`.

### Schema-difference strategy

Three categories of schema differences; each has a different response:

1. **Version-dependent fields** — present only on certain Claude versions. Parse `version` first; gate optional decode on it.
2. **Legitimately absent fields** — Claude documents them as optional (`pr`, `pr.review_state`, `rate_limits`, `context_window.current_usage`). Use `T?` with `decodeIfPresent`.
3. **Wrong source** — the app owns the fact and has a better source than Claude (e.g. `pr` from gh, `repo` from git, line counts from `git diff --shortstat HEAD`). Exclude from `CodingKeys` and set post-decode.

Catch-all "lenient" decoders (decode whatever arrives without validation) are not used. Each added field is an explicit decision about source and nullability.

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
| `statusline.payload.decode_failed` | `pane.name`, `reason`, `error`, `byte_count`, `payload_prefix`, `decoding_error_kind`, `coding_path`†, `missing_key`† | I7: read or JSON decode failure. `decoding_error_kind`: `key_not_found`, `type_mismatch`, `value_not_found`, `data_corrupted`, or `decoding_error`. †Present only for `key_not_found` and `type_mismatch`. |
| `statusline.payload.stale_recovered` | `pane.name`, `file_mtime`, `stale_age_seconds` | I6: vnode watcher missed a write; timer recovered |
| `statusline.codex.hook_waiting` | `pane.id`, `pane.name`, `tab.id`, `tab.name`, `retry_attempt`, `late_bound`, `hook_record_available` | Codex provider is still waiting for a hook record |
| `statusline.codex.hook_bound` | `pane.id`, `pane.name`, `tab.id`, `tab.name`, `hook_record_available`, `hook_event_name`, `retry_attempt`, `late_bound`, `session_id_prefix`, `transcript_available` | Codex hook record bound the pane to a session |
| `statusline.codex.hook_record_ignored` | `pane.id`, `pane.name`, `tab.id`, `tab.name`, `reason`, `retry_attempt`, `late_bound`, `record_pane_id`, `record_tab_id`, `hook_event_name` | Codex hook record was present but rejected |
| `statusline.codex.sqlite_enrichment` | `pane.id`, `pane.name`, `tab.id`, `tab.name`, `result`, `retry_attempt`, `session_id_prefix`, `rollout_path_matched` | Codex SQLite enrichment by exact session id/path |
| `statusline.codex.selection_failed` | `pane.id`, `pane.name`, `tab.id`, `tab.name`, `reason`, `retry_attempt`, `retry_reason`, `hook_record_available`, `hook_event_name` | Codex hook binding failed or was still waiting |
| `statusline.codex.tailer_started` | `pane.id`, `pane.name`, `tab.id`, `tab.name` | Codex transcript tailer starts |
| `statusline.codex.tailer_read` | `pane.id`, `pane.name`, `tab.id`, `tab.name`, `line_count`, `update_count`, `catch_up` | Codex rollout tailer reads a bounded batch |
| `statusline.codex.parsed_update` | `pane.id`, `pane.name`, `tab.id`, `tab.name`, `has_model`, `has_tokens`, `has_context`, `has_rate_limits` | Codex rollout parsing produced a supported update |
