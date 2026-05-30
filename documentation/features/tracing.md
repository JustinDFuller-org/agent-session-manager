# Tracing

Agent Session Manager emits OpenTelemetry spans for all I/O operations. Tracing is off by default and can be enabled in **Settings → Debug**.

## Configuration

- **Enable Debug Mode** — master switch (default: off). Spans are written to files immediately on enable.
- **Traces Directory** — fixed at `~/Library/Application Support/agent-session-manager/traces/`
- **Max File Size (per pane)** — fixed 10 MB trim threshold per pane file

## File Layout

Spans are written as JSON-Lines files, organized by tab and pane:

```
traces/
  <tab-name>-<tab-id8>/
    <pane-name>-<pane-id8>.jsonl   ← per-pane span file
  _global/
    global.jsonl                   ← spans without a pane.id
```

Each file begins with a metadata header line:

```json
{"_type":"metadata","tabId":"...","tabName":"...","paneId":"...","paneName":"...","createdAt":"..."}
```

Subsequent lines are span objects (JSON-Lines format):

```json
{"name":"tab.pane.added","traceId":"...","spanId":"...","startEpochMs":1716000000000,"endEpochMs":1716000000001,"durationMs":1,"attributes":{"pane.id":"...","pane.name":"my-feature","tab.id":"...","tab.name":"my-repo"}}
```

## Retention

Files older than **1 day** are automatically deleted by `TraceCleanupService` on app launch. The `trace.cleanup.ran` span is emitted to the `_global` file after each cleanup run.

## Span Routing

Spans are routed to files by `pane.id` and `tab.id` attributes:

| Attributes present | Destination |
|--------------------|-------------|
| `pane.id` + `tab.id` | `traces/<tab-name>-<tab-id8>/<pane-name>-<pane-id8>.jsonl` |
| neither | `traces/_global/global.jsonl` |

## Span Catalog

### App lifecycle
| Span | Key Attributes |
|------|---------------|
| `app.started` | `os.version`, `app.version`, `cpu.arch` |
| `tab.added` | `tab.name`, `tab.directory` |
| `tab.closed` | `tab.name` |
| `pane.activated` | `pane.id`, `pane.name`, `tab.id`, `tab.name` |
| `pane.notification.added` | `pane.id`, `pane.name`, `tab.id`, `tab.name`, `notification.kind` |
| `trace.cleanup.ran` | `deleted_count`, `retained_count` |

### Terminal
| Span | Key Attributes |
|------|---------------|
| `terminal.process.started` | `executable`, `args`, `pane.id`, `pane.name`, `tab.id`, `tab.name` |
| `terminal.process.exited` | `exit_code`, `pane.id`, `pane.name` |
| `terminal.attention.delivered` | `source` (`bell`/`osc777`), `pane.id`, `pane.name` |

### Git / Worktrees
| Span | Key Attributes |
|------|---------------|
| `tab.git.command` | `cwd`, `args` |
| `tab.worktree.resolved` | `user_ref`, `path` |
| `tab.pane.added` | `pane.id`, `pane.name`, `tab.id`, `tab.name` |

### Status Line
| Span | Key Attributes |
|------|---------------|
| `statusline.monitor.started` | `pane.id`, `pane.name` |
| `statusline.settings_file.written` | `path`, `bytes` |
| `statusline.attention.received` | `pane.id`, `pane.name` |
| `statusline.pr_transition` | `old_state`, `new_state` |
| `statusline.worktree.name_mismatch` | `pane.name`, `field`, `computed`, `reported` |
| `statusline.lines.source_mismatch` | `pane.name`, `computed_added`, `reported_added`, `computed_removed`, `reported_removed` |
| `statusline.migration.gitworktree_dropped` | `row_index`, `position` |
| `statusline.migration.worktreebranch_merged` | `row_index`, `position`, `substituted` |

### Notifications
| Span | Key Attributes |
|------|---------------|
| `notification.auth.requested` | `result` |
| `notification.pane_attention.posted` | `pane.name` |
| `notification.pr_merged.posted` | `pane.name`, `pr.title` |

### PR Tracking
| Span | Key Attributes |
|------|---------------|
| `pr.poll.cycle` | `pane_count`, `result` |
| `pr.graphql.query` | `pane_count`, `result` |

### Settings
| Span | Key Attributes |
|------|---------------|
| `settings.saved` | `file`, `bytes` |
| `settings.restored` | `file`, `result` |

## Viewing Traces

Use `jq` to inspect a pane's file:

```bash
TRACES=~/Library/Application\ Support/agent-session-manager/traces
# List all pane files
find "$TRACES" -name '*.jsonl'

# Pretty-print spans from a specific pane file (skipping the metadata header)
jq 'select(._type != "metadata")' "$TRACES/<tab-dir>/<pane-file>.jsonl"

# Filter by span name
jq 'select(.name == "terminal.process.started")' "$TRACES/<tab-dir>/<pane-file>.jsonl"
```

Or open the in-app **Trace Dashboard** (⌘⇧D) for a visual waterfall view.
