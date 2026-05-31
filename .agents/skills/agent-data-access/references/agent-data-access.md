# Agent Data Access

Read-only reference for accessing Agent Session Manager runtime data from an agent context. All data lives on disk — no IPC or API calls required.

> **Access is read-only.** Do not write to these files or their containing directory.

---

## Base Directory

```
~/Library/Application Support/agent-session-manager/
```

All paths below are relative to this base unless noted.

---

## Settings

Settings files are always present after first app launch. All are plain JSON and can be read with `cat` or `jq`.

| File | Contents |
|------|----------|
| `settings.json` | Claude CLI options |
| `codex-settings.json` | Codex CLI options |
| `cursor-settings.json` | Cursor CLI options |
| `statusline-settings.json` | Status line display settings |
| `active-tools-settings.json` | Which agent tools are active |
| `default-branch.json` | Default git branch setting |
| `notification-settings.json` | macOS notification preferences |
| `restart-settings.json` | Auto-restart behavior |
| `worktree-cleanup.json` | Worktree cleanup policy |
| `existing-worktree-management.json` | How existing worktrees are managed |
| `debug-settings.json` | Unified Debug mode enabled state |
| `pr-tracking-settings.json` | PR tracking preferences |
| `pr-polling-settings.json` | PR polling interval |
| `terminal-settings.json` | Terminal rendering settings |
| `worktree-base-ref.json` | Base ref for new worktrees |
| `exit-behavior.json` | App exit behavior |
| `env-var-settings.json` | Environment variable config |
| `profiles.json` | Named profiles |
| `session-name-settings.json` | Session naming settings |

**Example — read all settings as pretty JSON:**

```bash
BASE=~/Library/Application\ Support/agent-session-manager
jq '.' "$BASE/settings.json"
jq '.' "$BASE/debug-settings.json"
```

---

## Traces

Traces are **off by default**. The user must enable them in **Settings → Debug**.

**Check if tracing is enabled:**

```bash
jq '.enabled' \
  ~/Library/Application\ Support/agent-session-manager/debug-settings.json
```

**Default traces directory:**

```
~/Library/Application Support/agent-session-manager/traces/
```

The traces directory is fixed.

**Directory layout:**

```
traces/
  <tab-name>-<tab-id8>/
    <pane-name>-<pane-id8>.jsonl   ← per-pane span file
  _global/
    global.jsonl                   ← spans without a pane.id
```

Each file begins with a `{"_type":"metadata",…}` header line followed by JSON-Lines span objects.

### Format

JSON-Lines: one span object per line.

```json
{"name":"terminal.process.started","traceId":"...","spanId":"...","parentSpanId":"...","startEpochMs":1716000000000,"endEpochMs":1716000000001,"durationMs":1,"attributes":{"executable":"claude","pane.name":"my-feature","tab.name":"my-repo"}}
```

Schema:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Span name (see catalog below) |
| `traceId` | string | Trace identifier |
| `spanId` | string | Span identifier |
| `parentSpanId` | string? | Parent span (omitted for root spans) |
| `startEpochMs` | number | Start time (Unix ms) |
| `endEpochMs` | number | End time (Unix ms) |
| `durationMs` | number | Duration in milliseconds |
| `attributes` | object | Span-specific key/value pairs |

### Span Catalog

**App lifecycle**

| Span | Key Attributes |
|------|----------------|
| `app.started` | `os.version`, `app.version`, `cpu.arch` |
| `tab.added` | `tab.name`, `tab.directory` |
| `tab.closed` | `tab.name` |
| `pane.activated` | `pane.name`, `tab.name` |
| `pane.notification.added` | `pane.name`, `tab.name`, `notification.kind` |

**Terminal**

| Span | Key Attributes |
|------|----------------|
| `terminal.process.started` | `executable`, `args`, `pane.name`, `tab.name` |
| `terminal.process.exited` | `exit_code`, `pane.name` |
| `terminal.attention.delivered` | `source` (`bell`/`osc777`), `pane.name` |

**Git / Worktrees**

| Span | Key Attributes |
|------|----------------|
| `tab.git.command` | `cwd`, `args` |
| `tab.worktree.resolved` | `user_ref`, `path` |
| `tab.pane.added` | `pane.name`, `tab.name` |

**Status Line**

| Span | Key Attributes |
|------|----------------|
| `statusline.monitor.started` | `pane.name` |
| `statusline.settings_file.written` | `path`, `bytes` |
| `statusline.attention.received` | `pane.name` |
| `statusline.pr_transition` | `old_state`, `new_state` |

**Notifications**

| Span | Key Attributes |
|------|----------------|
| `notification.auth.requested` | `result` |
| `notification.pane_attention.posted` | `pane.name` |
| `notification.pr_merged.posted` | `pane.name`, `pr.title` |

**PR Tracking**

| Span | Key Attributes |
|------|----------------|
| `pr.poll.cycle` | `pane_count`, `result` |
| `pr.graphql.query` | `pane_count`, `result` |

**Settings**

| Span | Key Attributes |
|------|----------------|
| `settings.saved` | `file`, `bytes` |
| `settings.restored` | `file`, `result` |

### Example jq Queries

```bash
TRACES=~/Library/Application\ Support/agent-session-manager/traces

# List all pane files
find "$TRACES" -name '*.jsonl'

# Pretty-print spans from a pane file (skip the metadata header)
jq 'select(._type != "metadata")' "$TRACES/<tab-dir>/<pane-file>.jsonl"

# Filter to a specific span name across all pane files
find "$TRACES" -name '*.jsonl' -exec \
  jq 'select(._type != "metadata" and .name == "terminal.process.started")' {} \;

# Show only span name and duration, sorted by duration descending (single file)
jq -s '[.[] | select(._type != "metadata")] | sort_by(-.durationMs) | .[] | {name, durationMs}' \
  "$TRACES/<tab-dir>/<pane-file>.jsonl"

# Count spans by name (single file)
jq -s '[.[] | select(._type != "metadata")] | group_by(.name) | map({name: .[0].name, count: length}) | sort_by(-.count)[]' \
  "$TRACES/<tab-dir>/<pane-file>.jsonl"
```

See `feature-tracing` for deeper tracing documentation.

---

## Invariants

Invariant logging is enabled by the same **Settings → Debug** switch as tracing.

```text
invariants/
  invariants.jsonl
```

Each valid record contains an occurrence UUID, stable invariant ID, integration, severity, description, timestamp, and context dictionary. Repeated IDs are separate occurrences.

```bash
jq 'select(._type != "metadata")' \
  ~/Library/Application\ Support/agent-session-manager/invariants/invariants.jsonl
```

See `feature-invariants` for deeper invariant reporting documentation.
