---
name: agent-data-access
description: "Read-only Agent Session Manager runtime diagnosis using sessions, current per-pane traces, invariants, global correlation, and separately reported legacy files. Load when investigating prod or dev behavior on a named tab or pane."
compatibility: "Requires macOS bash, jq, find, and date."
---

# Agent Data Access

Use the bundled collector for incident diagnosis. It reads local files only and emits raw JSON:

```bash
.agents/skills/agent-data-access/scripts/collect-telemetry.sh \
  --app prod \
  --tab "Agent Session Manager" \
  --pane "telemetry-skill"
```

## Incident Workflow

1. Ask whether the report came from `prod` or `dev`. Never guess.
2. Run the collector with the reported tab and pane names. Use `--list` first if the identity is unclear.
3. Inspect `currentSessionMatches`, `candidateTraceFiles`, `paneSpans`, and `matchingInvariantViolations`.
4. Correlate `correlatedGlobalSpans` in the same time window.
5. If pane names are duplicated, retain every historical candidate or narrow with `--pane-id`.
6. Widen `--since` when the relevant activity falls outside the default one-hour window.

See [references/agent-data-access.md](references/agent-data-access.md) for formats, options, retention, and manual read-only queries. See [references/examples.md](references/examples.md) for commands and captured prod/dev output.
