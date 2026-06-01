# Debug Mode

Debug mode is the single switch for durable diagnostic output. It is off by default.

Production writes under `~/Library/Application Support/agent-session-manager/`. Development builds use the isolated `~/Library/Application Support/agent-session-manager.dev/` directory.

Production writes under `~/Library/Application Support/agent-session-manager/`. Development builds use the isolated `~/Library/Application Support/agent-session-manager.dev/` directory.

## Settings

Open **Settings → Debug** and enable **Enable Debug Mode**. The setting persists in:

```text
~/Library/Application Support/agent-session-manager/debug-settings.json
```

The schema is:

```json
{"schemaVersion":1,"enabled":true}
```

Older `debug-settings.json` schemas and the removed `tracing-settings.json` file are ignored instead of migrated, so upgrades start with Debug mode disabled.

## Output

Debug mode enables both:

- OpenTelemetry JSONL traces under `traces/`
- invariant JSONL violations under `invariants/invariants.jsonl`

Both outputs use fixed 10 MB caps. Trace files retain their existing one-day cleanup behavior. Invariant logs are size-bounded only so violations remain available during dogfooding.

Top-level `debug-trace.log` and `traces.jsonl` files are stale legacy formats when present. Report them separately from current per-pane traces.

Top-level `debug-trace.log` and `traces.jsonl` files are stale legacy formats when present. Report them separately from current per-pane traces.

Use **Open Trace Dashboard** or **Open Invariant Dashboard** from the Debug settings page. The same windows are available from the Window menu with `⌘⇧D` and `⌘⇧I`.
