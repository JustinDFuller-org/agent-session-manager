# Invariants

Agent Session Manager records contract violations separately from traces so repeated mismatches remain visible during dogfooding.

## Enabling

Open **Settings → Debug** and enable **Enable Debug Mode**. Violations are always routed through tracing, but durable invariant JSONL output is written only while Debug mode is enabled.

## Catalog

| ID | Integration | Severity | Legacy trace event |
|---|---|---|---|
| `statusline.worktree.name` | Status Line | warning | `statusline.worktree.name_mismatch` |
| `statusline.lines.source` | Status Line | warning | `statusline.lines.source_mismatch` |

Each occurrence has its own UUID. Repeated violations of the same invariant remain separate dashboard rows.

## File

Violations are appended synchronously to:

```text
~/Library/Application Support/agent-session-manager/invariants/invariants.jsonl
```

The file starts with versioned metadata and is trimmed to 10 MB with an invariant-specific marker. It is size-bounded only; the trace retention cleanup does not delete it.

## Dashboard

Open **Invariant Dashboard** from **Settings → Debug**, the Window menu, or `⌘⇧I`. The dashboard shows newest violations first, supports filtering, and displays the selected occurrence context.
