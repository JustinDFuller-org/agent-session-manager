---
name: instrument-runtime-telemetry
description: "Mandatory telemetry checklist for Agent Session Manager runtime behavior features, fixes, and refactors. Load before changing runtime behavior so spans, invariants, tests, and catalogs stay diagnostically complete."
---

# Instrument Runtime Telemetry

Load this skill for every feature, bug fix, or refactor that changes runtime behavior. This checklist applies even when telemetry is not the primary feature.

## Choose The Signal

- Emit a span for operations, lifecycle transitions, meaningful points in time, and success or failure outcomes.
- Use span attributes for operation context and events for meaningful points during a long-lived operation.
- Report an invariant when a runtime contract is violated and the occurrence must remain visible as a separate diagnostic record.
- Use both when an invariant occurrence also belongs in trace correlation.
- Every `TracingService` span/record call automatically forwards to unified logging (`os.Logger`
  via `AppLog`) and an Instruments signpost — always on, independent of Debug Mode. Do not add
  `print`, `NSLog`, or a separate log call alongside a span for the same event; the span is the
  single instrumentation point.
- If you need a *direct* `AppLog` call outside a span (rare — most events should just be a span),
  follow the same privacy split as `AppLog.log`: event name `.public` (a static string), attribute
  values `.private` (they may carry `cwd`, git args, or error strings).

## Required Context

Every pane-scoped span must include:

```text
pane.id
pane.name
tab.id
tab.name
```

Record a bounded `result` or failure attribute for operations with meaningful outcomes. End every started long-lived span on all success, failure, cancellation, and early-return paths.

## Data Rules

- Keep local telemetry bounded and compatible with existing retention and trimming.
- Do not expose app plumbing in terminal panes. Preserve Terminal Purity.
- Do not add secrets, environment-variable values, auth material, or terminal-content capture.
- Keep payload excerpts tightly bounded and add them only when they are required for diagnosis.
- Update telemetry tests and the tracing, debug-mode, or invariant catalog when runtime telemetry changes.

## Prioritized Backlog

Record these as future production instrumentation work; do not fold them into unrelated changes:

1. Add stronger correlation IDs across pane lifecycle, status-line, and PR-tracking paths.
2. Emit app startup and build metadata. Partially satisfied: the OTel `Resource` on every trace
   file's metadata header already carries `service.version`, `os.*`, and `device.*` (see
   `documentation/features/tracing.md`). Startup-event-level metadata (e.g. a `app.launched` span)
   is still open.
3. Complete pane create, restore, close, restart, and shell lifecycle coverage.
4. Add explicit failure outcomes for worktree, terminal, settings, and notification operations.
5. Surface exporter write and trim failures.
6. Surface provider and watcher setup/read failures.
7. Close PR-cycle spans on every early return and report skipped outcomes.

Use OpenTelemetry span concepts consistently: attributes describe context, events mark meaningful moments, and failed operations carry error status or an equivalent bounded result field.
