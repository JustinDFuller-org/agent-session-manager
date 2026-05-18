# Tracing

Agent Session Manager emits OpenTelemetry spans for all I/O operations. Tracing is off by default and can be enabled in **Settings → Tracing**.

## Configuration

- **Enable Tracing** — master switch (default: off)
- **Output** — `stdout` or `file`
- **File Path** — custom path (empty = `~/Library/Application Support/agent-session-manager/traces.jsonl`)
- **Max File Size** — trim threshold (default: 10 MB)

## Output Format

Each span is one JSON object on its own line (JSON-Lines):

```json
{"name":"tab.pane.added","traceId":"...","spanId":"...","startEpochMs":1716000000000,"endEpochMs":1716000000001,"durationMs":1,"attributes":{"pane.name":"my-feature","tab.name":"my-repo"}}
```

## Span Catalog

### App lifecycle
| Span | Key Attributes |
|------|---------------|
| `app.started` | `os.version`, `app.version`, `cpu.arch` |
| `tab.added` | `tab.name`, `tab.directory` |
| `tab.closed` | `tab.name` |
| `pane.activated` | `pane.name`, `tab.name` |
| `pane.notification.added` | `pane.name`, `tab.name`, `notification.kind` |

### Terminal
| Span | Key Attributes |
|------|---------------|
| `terminal.process.started` | `executable`, `args`, `pane.name`, `tab.name` |
| `terminal.process.exited` | `exit_code`, `pane.name` |
| `terminal.attention.delivered` | `source` (`bell`/`osc777`), `pane.name` |

### Git / Worktrees
| Span | Key Attributes |
|------|---------------|
| `tab.git.command` | `cwd`, `args` |
| `tab.worktree.resolved` | `user_ref`, `path` |
| `tab.pane.added` | `pane.name`, `tab.name` |

### Status Line
| Span | Key Attributes |
|------|---------------|
| `statusline.monitor.started` | `pane.name` |
| `statusline.settings_file.written` | `path`, `bytes` |
| `statusline.attention.received` | `pane.name` |
| `statusline.pr_transition` | `old_state`, `new_state` |

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

With output set to **file**, open the file with `jq`:

```bash
cat ~/Library/Application\ Support/agent-session-manager/traces.jsonl | jq '.'
```

Filter by span name:

```bash
cat traces.jsonl | jq 'select(.name == "terminal.process.started")'
```

With output set to **stdout**, spans appear in the console when running `make run`.
