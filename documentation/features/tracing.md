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

`PerPaneSpanExporter` confines its pane-id-to-file cache to its own serial queue, so it cannot race
even if it is ever attached to a processor with different internal threading than
`SimpleSpanProcessor`'s. Before creating a file for a pane id it hasn't seen yet, it also checks
whether a file already exists on disk under that id's 8-character suffix, regardless of name —
`TracingService.configure` builds a brand-new exporter (with an empty in-memory cache) on every
Debug Mode toggle, and without this check a pane whose name attributes differ across that boundary
(including a transient "unknown" before names resolve) would fork its trace into two files.

## App Lifecycle Correlation

The app writes `app-lifecycle.json` in its application-support directory through
`ApplicationLifecycleMarker`, which also carries the current peak resident footprint
(`task_vm_info.phys_footprint`) on every write. States:

- `running` — written at launch with a launch UUID, then refreshed every 60 seconds by a heartbeat
  timer so the marker's `timestamp` and peak footprint stay current while the app is alive.
- `terminating` — written when `applicationShouldTerminate` is called, before any teardown await.
- `clean` — written from `applicationWillTerminate`, which only runs once AppKit has confirmed the
  process is actually going away.

A write to `terminating` or `clean` only succeeds when the on-disk marker still belongs to the calling
launch's UUID; this ownership check prevents an older concurrent instance from marking a newer
instance's exit, and an interprocess file lock keeps the read/check/write sequence atomic across
instances. A later launch classifies the previous exit from the marker it finds: `clean` reports
`previous_exit=clean`; `running` (no termination was ever requested) reports `previous_exit=unclean`;
`terminating` (termination was requested but the process died before confirming) reports
`previous_exit=unclean_during_teardown`; a missing, unsupported, or unreadable marker reports
`previous_exit=unknown`.

`app.launched` records the previous-exit classification and marker write result after tracing is
configured; an `unclean` or `unclean_during_teardown` previous exit also raises the
`app.lifecycle.previous_exit_clean` invariant (see `documentation/features/invariants.md`), carrying the
previous process's last heartbeat time and peak footprint in the violation context.
`app.termination.requested` (emitted from `applicationWillTerminate`) records whether the clean marker
was written. A force kill, signal crash, or power loss cannot emit a final span, so the next launch's
marker classification is the durable evidence for an unclean process exit.

`applicationShouldTerminate` replies to AppKit at most once, from whichever finishes first: Agent
Control's async shutdown, or a bounded deadline timer. This exists because an unbounded await between
`terminateLater` and the reply can leave the reply unreachable for an arbitrary time if the awaited work
stalls — the process keeps running with no further shutdown code able to execute.

## Auto-forwarding to other signals

Every `TracingService.startSpan`/`record`/`withSpan` call also, unconditionally:

- writes a unified-log line via `AppLog` (see `documentation/features/debug-logging.md`) — always on,
  independent of Debug Mode
- emits an `os_signpost` interval (`OSSignposterIntegration`/`SignPostIntegration`) for Instruments'
  Points of Interest — also always on

Instrumenting a code path is a single `TracingService` call, not three. Do not add separate
`print`/`NSLog`/log calls alongside a span for the same event.

Each file rotates at the fixed 10 MB cap: `JSONLTrimmer` renames it to `<name>.1.jsonl` and starts a
fresh file carrying a copy of the metadata header, rather than reading and rewriting the whole
file in place. At most one rotated generation exists per file; a second rotation replaces it.
`TraceCleanupService` removes both active and rotated `.jsonl` files older than one day (and,
after 300 seconds, any orphaned `*.sb-*` atomic-write temporary) on app launch and every 6 hours,
and emits `trace.cleanup.ran`. It also reclaims the legacy root-level `debug-trace.log` and
`traces.jsonl` files and applies the same rotation-aware cleanup to `invariants/`.

## Current Span Catalog

| Area | Spans |
|---|---|
| Pane lifecycle | `pane.activated`, `pane.focus_mode.changed`, `pane.notification.added`, `pane.notification.cleared`, `pane.activity.changed`, `pane.pr_merged.cleared`, `pane.pr_closed.cleared`, `tab.pane.added`, `tab.worktree.resolved` |
| Session restore | `session.pane.restore.continuation` |
| App lifecycle | `app.launched`, `app.termination.requested` |
| Profiles | `profile.save` |
| Agent control | `agent_control.injection_decision.resolved`, `agent_control.server.starting`, `agent_control.server.started`, `agent_control.server.start_failed`, `agent_control.server.stopped`, `agent_control.credential.registered`, `agent_control.credential.revoked`, `agent_control.scope.updated`, `agent_control.session.bound`, `agent_control.session.closed`, `agent_control.request.authorization_failed`, `agent_control.request.cancelled`, `agent_control.request.timed_out`, `agent_control.request.response_too_large`, `agent_control.request.stream_failed`, `agent_control.resource.read`, `agent_control.mutation`, `agent_control.harness.prepare`, `agent_control.diagnostic.query`, `agent_control.tool.authorization_denied`, `agent_control.debug_mode.changed` |
| Terminal | `terminal.process.started`, `terminal.process.exited`, `terminal.attention.delivered`, `terminal.clipboard.copied`, `terminal.clipboard.pasted`, `terminal.scrollback.changed` |
| Status line | `statusline.monitor.started`, `statusline.monitor.stopped`, `statusline.settings_file.written`, `statusline.attention.received`, `statusline.payload.applied`, `statusline.payload.decode_failed`, `statusline.payload.stale_recovered`, `statusline.pr_transition`, `statusline.migration.gitworktree_dropped`, `statusline.migration.worktreebranch_merged`, `statusline.custom_field.exec_started`, `statusline.custom_field.exec_succeeded`, `statusline.custom_field.exec_failed`, `statusline.custom_field.exec_stale`, `statusline.custom_field.run_now`, `statusline.hook.event` |
| Invariants | `statusline.worktree.name_mismatch`, `statusline.lines.source_mismatch`, `app.bundle_identity.preferred_url_mismatch`, `cursor.agent_control.bridge_missing`, `app.launch.auxiliary_window_opened`, `app.launch.auxiliary_windows_checked`, `invariant.log.write_failed`, `terminal.clipboard.copy_without_selection`, `app.lifecycle.previous_exit_unclean`, `process.output_read.timed_out` |
| Notifications | `notification.auth.requested`, `notification.pane_attention.posted`, `notification.pane_attention.skipped`, `notification.pr_merged.posted`, `notification.pr_merged.skipped`, `notification.pr_closed.posted`, `notification.pr_closed.skipped`, `notification.response.navigation` |
| PR tracking | `pr.poll.cycle`, `pr.graphql.query`, `pr.response.parsed`, `pr.result.delivered`, `session.pr_check` |
| OpenCode | `opencode.port.allocated`, `opencode.port_allocation.failed`, `opencode.command.built`, `opencode.session.resumed`, `opencode.config_content.injected`, `opencode.config_content.user_override_silenced`, `statusline.opencode.server.bound`, `statusline.opencode.session.bound`, `statusline.opencode.session.expected_missing`, `statusline.opencode.session.waiting_for_create`, `statusline.opencode.session.unbindable`, `statusline.opencode.session.named`, `statusline.opencode.session.rename_failed`, `statusline.opencode.poll.success`, `statusline.opencode.poll.failed`, `statusline.opencode.sse.connecting`, `statusline.opencode.sse.connected`, `statusline.opencode.sse.disconnected`, `statusline.opencode.sse.exhausted`, `statusline.opencode.sse.session_idle`, `statusline.opencode.permission.fired`, `statusline.opencode.stop.fired`, `statusline.opencode.stop.received`, `statusline.opencode.session.bound.received`, `statusline.opencode.version.drift` |
| Updates | `update.check.dmg.ran`, `update.dmg.will_install`, `update.dmg.should_relaunch`, `update.dmg.will_relaunch`, `update.dmg.will_install_on_quit` |
| Other | `trace.cleanup.ran`, `window.snapshot`, `process.output_read.timed_out` |

Not every existing span is pane scoped. Pane-scoped spans should carry `pane.id`, `pane.name`, `tab.id`, and `tab.name`; runtime changes must follow `instrument-runtime-telemetry`.

## Diagnosis

Use the metadata-aware read-only collector:

```bash
.agents/skills/agent-data-access/scripts/collect-telemetry.sh \
  --app prod \
  --tab "Agent Session Manager" \
  --pane "telemetry-skill"
```

The top-level historical `debug-trace.log` and `traces.jsonl` files are legacy formats nothing
writes anymore; `TraceCleanupService` deletes them on the next cleanup pass if found. Inventory
them separately from current per-pane JSONL output when diagnosing an older data directory.
