# Tracing

Agent Session Manager writes bounded OpenTelemetry JSONL spans while **Settings → Debug → Enable Debug Mode** is enabled.

## App Modes

Production writes under `~/Library/Application Support/agent-session-manager/`. Development builds write under `~/Library/Application Support/agent-session-manager.dev/`.

## File Layout

```text
traces/
  <sanitized-tab-name>-<tab-id8>/
    <sanitized-pane-name>-<pane-id8>.jsonl
  _global/
    global.jsonl
```

Each file begins with a metadata header:

```json
{"_type":"metadata","paneId":"...","paneName":"...","tabId":"...","tabName":"...","createdAt":"..."}
```

The exporter routes every span with `pane.id` to a pane file. Spans without `pane.id` route to `_global/global.jsonl`. Tab and pane names are sanitized only for paths; diagnosis should read metadata rather than derive filenames.

Each file is trimmed at the fixed 10 MB cap. `TraceCleanupService` removes files older than one day on app launch and emits `trace.cleanup.ran`.

## Current Span Catalog

| Area | Spans |
|---|---|
| Pane lifecycle | `pane.activated`, `pane.focus_mode.changed`, `pane.notification.added`, `pane.notification.cleared`, `pane.activity.changed`, `tab.pane.added`, `tab.worktree.resolved` |
| Terminal | `terminal.process.started`, `terminal.process.exited`, `terminal.attention.delivered` |
| Status line | `statusline.monitor.started`, `statusline.monitor.stopped`, `statusline.settings_file.written`, `statusline.attention.received`, `statusline.payload.applied`, `statusline.payload.decode_failed`, `statusline.payload.stale_recovered`, `statusline.pr_transition`, `statusline.migration.gitworktree_dropped`, `statusline.migration.worktreebranch_merged` |
| Invariants | `statusline.worktree.name_mismatch`, `statusline.lines.source_mismatch`, `app.bundle_identity.preferred_url_mismatch`, `invariant.log.write_failed` |
| Notifications | `notification.auth.requested`, `notification.pane_attention.posted`, `notification.pane_attention.skipped`, `notification.pr_merged.posted`, `notification.pr_merged.skipped`, `notification.response.navigation` |
| PR tracking | `pr.poll.cycle`, `pr.graphql.query`, `pr.response.parsed`, `session.pr_check` |
| Other | `trace.cleanup.ran`, `window.snapshot` |

Not every existing span is pane scoped. Pane-scoped spans should carry `pane.id`, `pane.name`, `tab.id`, and `tab.name`; runtime changes must follow `instrument-runtime-telemetry`.

## Diagnosis

Use the metadata-aware read-only collector:

```bash
.agents/skills/agent-data-access/scripts/collect-telemetry.sh \
  --app prod \
  --tab "Agent Session Manager" \
  --pane "telemetry-skill"
```

The top-level historical `debug-trace.log` and `traces.jsonl` files are legacy formats. Inventory them separately; do not merge them with current per-pane JSONL output.
