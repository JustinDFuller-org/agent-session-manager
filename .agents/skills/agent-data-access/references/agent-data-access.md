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
| `opencode-settings.json` | OpenCode CLI options |
| `statusline-settings.json` | Status line display settings |
| `active-tools-settings.json` | Which agent tools are active |
| `default-branch.json` | Default git branch setting |
| `notification-settings.json` | macOS notification preferences |
| `restart-settings.json` | Auto-restart behavior |
| `worktree-cleanup.json` | Worktree cleanup policy |
| `existing-worktree-management.json` | How existing worktrees are managed |
| `tracing-settings.json` | Tracing enabled/output target/file path |
| `pr-tracking-settings.json` | PR tracking preferences |
| `pr-polling-settings.json` | PR polling interval |
| `terminal-settings.json` | Terminal rendering settings |
| `worktree-base-ref.json` | Base ref for new worktrees |
| `exit-behavior.json` | App exit behavior |
| `env-var-settings.json` | Environment variable config |
| `profiles.json` | Named profiles |
| `session-name-settings.json` | Session naming settings |
| `debug-settings.json` | Debug logging enabled/file path/max size |

**Example — read all settings as pretty JSON:**

```bash
BASE=~/Library/Application\ Support/agent-session-manager
jq '.' "$BASE/settings.json"
jq '.' "$BASE/tracing-settings.json"
```

---

## Traces

Traces are **off by default**. The user must enable them in **Settings → Tracing** and set the output target to **file**.

**Check if file tracing is enabled:**

```bash
jq '{enabled: .enabled, output: .outputTarget}' \
  ~/Library/Application\ Support/agent-session-manager/tracing-settings.json
```

File tracing is active when `enabled` is `true` and `outputTarget` is `"file"`.

**Default file path:**

```
~/Library/Application Support/agent-session-manager/traces.jsonl
```

(The user may have configured a custom path; check `filePath` in `tracing-settings.json`.)

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
TRACES=~/Library/Application\ Support/agent-session-manager/traces.jsonl

# All spans, pretty-printed
jq '.' "$TRACES"

# Filter to a specific span name
jq 'select(.name == "terminal.process.started")' "$TRACES"

# Show only span name and duration, sorted by duration descending
jq -s 'sort_by(-.durationMs) | .[] | {name, durationMs}' "$TRACES"

# Show all process launches (executable + args)
jq 'select(.name == "terminal.process.started") | .attributes | {executable, args}' "$TRACES"

# Count spans by name
jq -s 'group_by(.name) | map({name: .[0].name, count: length}) | sort_by(-.count)[]' "$TRACES"
```

See `feature-tracing` for deeper tracing documentation.

---

## Debug Logs

Debug logging is **off by default**. The user must enable it in **Settings → General → Debug**.

**Check if debug logging is enabled:**

```bash
jq '.enabled' \
  ~/Library/Application\ Support/agent-session-manager/debug-settings.json
```

**Default file path:**

```
~/Library/Application Support/agent-session-manager/debug-trace.log
```

(The user may have configured a custom path; check the `path` field in `debug-settings.json`.)

### Format

Human-readable text, one entry per line, with timestamps. Example entries:

```
2024-05-18 12:00:01.234 [session] restored 3 tabs
2024-05-18 12:00:01.567 [git] cwd=/Users/user/project args=["status","--porcelain"]
2024-05-18 12:00:02.100 [worktree] resolved user_ref=issue-42 path=/Users/user/project/.worktrees/issue-42
2024-05-18 12:00:05.800 [notify] pane=my-feature kind=attention
2024-05-18 12:00:05.801 [banner] willPresent title="Attention needed"
```

### Contents

- Process launches (executable, arguments, working directory)
- Git commands (cwd, args)
- Worktree resolution (user ref → resolved path)
- Session save/restore events
- Notification and banner pipeline decisions
- Bell (`0x07`) and OSC 777 attention events
- Terminal snapshots (when terminal capture is enabled)
- Notification environment snapshots (UNUserNotificationCenter auth status)

### Example Commands

```bash
LOG=~/Library/Application\ Support/agent-session-manager/debug-trace.log

# Tail the log live
tail -f "$LOG"

# Show only git command lines
grep '\[git\]' "$LOG"

# Show notification-related lines
grep -E '\[(notify|banner)\]' "$LOG"

# Show last 100 lines
tail -100 "$LOG"
```

See `feature-debug-logging` for full debug logging documentation.
