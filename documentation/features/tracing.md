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
{
  "_type": "metadata",
  "paneId": "...", "paneName": "...", "tabId": "...", "tabName": "...", "createdAt": "...",
  "resource": {
    "service.name": "AgentSessionManager",
    "service.version": "...",
    "os.type": "darwin",
    "os.name": "macOS",
    "os.description": "...",
    "os.version": "...",
    "device.model.identifier": "...",
    "telemetry.sdk.name": "opentelemetry",
    "telemetry.sdk.language": "swift",
    "telemetry.sdk.version": "..."
  }
}
```

`resource` is the process-wide OTel `Resource` (`TracingService.configure`), written once per file
and identical across every file from the same process. It comes from
`ResourceExtension`'s `DefaultResources()` merged with an explicit `service.name`/`service.version`
override; `device.id` may also appear.

The exporter routes every span with `pane.id` to a pane file. Spans without `pane.id` route to `_global/global.jsonl`. Tab and pane names are sanitized only for paths; diagnosis should read metadata rather than derive filenames.

## Auto-forwarding to other signals

Every `TracingService.startSpan`/`record`/`withSpan` call also, unconditionally:

- writes a unified-log line via `AppLog` (see `documentation/features/debug-logging.md`) — always on,
  independent of Debug Mode
- emits an `os_signpost` interval (`OSSignposterIntegration`/`SignPostIntegration`) for Instruments'
  Points of Interest — also always on

Instrumenting a code path is a single `TracingService` call, not three. Do not add separate
`print`/`NSLog`/log calls alongside a span for the same event.

Each file is trimmed at the fixed 10 MB cap. `TraceCleanupService` removes files older than one day on app launch and emits `trace.cleanup.ran`.

## Current Span Catalog

| Area | Spans |
|---|---|
| Pane lifecycle | `pane.activated`, `pane.focus_mode.changed`, `pane.notification.added`, `pane.notification.cleared`, `pane.activity.changed`, `pane.pr_merged.cleared`, `pane.pr_closed.cleared`, `tab.pane.added`, `tab.worktree.resolved` |
| Agent control | `agent_control.injection_decision.resolved`, `agent_control.server.starting`, `agent_control.server.started`, `agent_control.server.start_failed`, `agent_control.server.stopped`, `agent_control.credential.registered`, `agent_control.credential.revoked`, `agent_control.scope.updated`, `agent_control.request.timed_out`, `agent_control.request.response_too_large`, `agent_control.request.stream_failed` |
| Terminal | `terminal.process.started`, `terminal.process.exited`, `terminal.attention.delivered` |
| Status line | `statusline.monitor.started`, `statusline.monitor.stopped`, `statusline.settings_file.written`, `statusline.attention.received`, `statusline.payload.applied`, `statusline.payload.decode_failed`, `statusline.payload.stale_recovered`, `statusline.pr_transition`, `statusline.migration.gitworktree_dropped`, `statusline.migration.worktreebranch_merged`, `statusline.hook.event` |
| Invariants | `statusline.worktree.name_mismatch`, `statusline.lines.source_mismatch`, `app.bundle_identity.preferred_url_mismatch`, `invariant.log.write_failed` |
| Notifications | `notification.auth.requested`, `notification.pane_attention.posted`, `notification.pane_attention.skipped`, `notification.pr_merged.posted`, `notification.pr_merged.skipped`, `notification.pr_closed.posted`, `notification.pr_closed.skipped`, `notification.response.navigation` |
| PR tracking | `pr.poll.cycle`, `pr.graphql.query`, `pr.response.parsed`, `session.pr_check` |
| OpenCode | `opencode.port.allocated`, `opencode.port_allocation.failed`, `opencode.command.built`, `opencode.session.resumed`, `opencode.config_content.injected`, `opencode.config_content.user_override_silenced`, `statusline.opencode.server.bound`, `statusline.opencode.session.bound`, `statusline.opencode.session.expected_missing`, `statusline.opencode.session.waiting_for_create`, `statusline.opencode.session.unbindable`, `statusline.opencode.session.named`, `statusline.opencode.session.rename_failed`, `statusline.opencode.poll.success`, `statusline.opencode.poll.failed`, `statusline.opencode.sse.connecting`, `statusline.opencode.sse.connected`, `statusline.opencode.sse.disconnected`, `statusline.opencode.sse.exhausted`, `statusline.opencode.sse.session_idle`, `statusline.opencode.permission.fired`, `statusline.opencode.stop.fired`, `statusline.opencode.stop.received`, `statusline.opencode.session.bound.received`, `statusline.opencode.version.drift` |
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
