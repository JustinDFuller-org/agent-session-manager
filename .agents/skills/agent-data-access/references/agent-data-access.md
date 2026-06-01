# Agent Data Access Reference

All access is read-only. Do not edit, delete, migrate, or merge telemetry files while diagnosing an incident.

## App Modes

Production and development builds intentionally use separate app-support directories:

| Mode | Directory |
|---|---|
| `prod` | `~/Library/Application Support/agent-session-manager/` |
| `dev` | `~/Library/Application Support/agent-session-manager.dev/` |

Always select the reported mode explicitly. Empty or missing files are valid, especially for `dev`.

## Collector

```bash
.agents/skills/agent-data-access/scripts/collect-telemetry.sh \
  --app <prod|dev> \
  [--list] \
  [--tab <name> --pane <name> | --pane-id <uuid-or-prefix>] \
  [--since <1h|24h|epoch-ms|RFC3339>] \
  [--until <epoch-ms|RFC3339>] \
  [--limit <count>] \
  [--support-dir <path>]
```

`--app` is required. `--since` defaults to `1h`; `--limit` defaults to `200`. `--support-dir` overrides the parent application-support directory for fixture testing or advanced inspection.

The collector returns stable JSON fields:

| Field | Contents |
|---|---|
| `debugMode` | Debug settings existence, enabled state, and raw JSON |
| `currentSessionMatches` | Matching panes from current `sessions.json` |
| `candidateTraceFiles` | Current-format pane files selected by metadata header |
| `paneSpans` | Raw selected pane spans within the time window |
| `matchingInvariantViolations` | Raw invariant records for candidate pane IDs |
| `correlatedGlobalSpans` | Raw `_global` spans in the same time window |
| `truncation` | Whether `--limit` omitted older matching records |
| `malformedLines` | Invalid JSONL counts by path |
| `legacyFiles` | Inventory of historical formats, reported separately |

## Current Formats

`sessions.json` maps current tabs and panes to UUIDs, names, harnesses, and worktrees. Closed panes may no longer exist there, but their trace metadata preserves their identity.

Current traces are JSONL files under `traces/`. Pane filenames are sanitized for storage, so diagnosis must scan metadata headers instead of deriving paths from names:

```json
{"_type":"metadata","paneId":"...","paneName":"...","tabId":"...","tabName":"...","createdAt":"..."}
```

Pane names are not unique over time. A tab/pane-name query intentionally returns every matching historical candidate. Use `--pane-id <uuid-or-prefix>` when the incident identifies one pane.

Spans without `pane.id` are written to `traces/_global/global.jsonl`. Correlate these spans by time window; do not assume they belong to one pane.

Invariant violations are stored in `invariants/invariants.jsonl`. Records include `context["pane.id"]` and `context["tab.id"]` when the reporting site supplies pane context.

Trace files older than one day are removed by `TraceCleanupService` on app launch. Per-pane traces and invariant output are also size bounded. Missing older records may be expected.

## Legacy Formats

These stale historical paths may coexist with current output:

```text
debug-trace.log
traces.jsonl
```

The collector reports them under `legacyFiles`. Never silently merge them into current per-pane JSONL results.

## Manual Read-Only Queries

```bash
BASE=~/Library/Application\ Support/agent-session-manager
jq '.' "$BASE/sessions.json"
jq '.' "$BASE/debug-settings.json"
find "$BASE/traces" -name '*.jsonl' -print
jq 'select(._type != "metadata")' "$BASE/invariants/invariants.jsonl"
```
