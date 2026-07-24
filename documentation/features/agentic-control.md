# Agent Control

Agent Control lets an injected agent inspect and operate Agent Session Manager
through an app-owned local Model Context Protocol (MCP) server. The app remains
the authority for tabs, panes, profiles, worktrees, settings, status lines, and
notifications.

## Configuration

Open **Settings** and choose:

- **Injection policy**: `Always`, `Never`, `Ask (on by default)`, or
  `Ask (off by default)`.
- **Scope**: `Pane`, `Tab`, or `Global`.

For an ask policy, the New Pane sheet shows the resolved Agent Session Manager
control toggle. The decision is persisted with the pane. Policy changes apply
to future launches, restores, and restarts; an already-running harness must be
restarted to receive a changed environment. Restarts replace injected control
configuration rather than accumulating arguments or credentials. Converting a
pane to a shell removes the control credential before the shell starts.

`Pane` scope is the default and permits access only to the source pane.
`Tab` scope includes the source tab and its panes. `Global` scope includes the
whole app and is required for global configuration changes and `debug.set_mode`.
Scope is enforced by every request, not only by the tool descriptions.

## Available MCP surface

Read-only resources provide scoped snapshots for:

- workspace, tabs, panes, profiles, harness catalogs, status-line configuration,
  notifications, and pane status data;
- diagnostic summary, current per-pane traces, invariant occurrences, and
  app-owned unified logs.

Profile resources contain only profiles referenced by panes visible to the
caller. Harness catalogs and global status-line configuration require Global
scope; pane- and tab-scoped status-line responses include only visible pane
data and profile overrides. Pane command arguments are field-redacted before
they leave the app.

Mutation tools provide narrowly scoped operations for:

- tab and pane creation, deletion, focus, restart, and reordering;
- profile lifecycle and ordering;
- harness enablement and CLI option configuration;
- global or profile-specific status-line configuration;
- notification acknowledgement and navigation;
- bounded diagnostic queries and Global-only Debug Mode changes.

Resources use stable IDs. Names are display values and are not addresses.
Stale IDs and out-of-scope IDs return structured errors.

## Harness support

Claude Code, OpenCode, and Codex receive app-owned, per-pane MCP
configuration before the final harness command starts. Credentials are
high-entropy bearer tokens held only in memory and passed through a runtime
environment variable. They are revoked when a pane or tab is torn down and are
never persisted, logged, or printed in the terminal.

Cursor injection is intentionally unsupported because its documented
configuration locations are project- or user-owned and do not provide a safe
per-pane surface. Agent Control reports an actionable setup error instead of
writing `.cursor/mcp.json` or `~/.cursor/mcp.json`.

OpenCode configuration is merged into the app-owned inline configuration;
existing user MCP entries and unrelated settings are preserved. Disabled or
declined injection leaves the normal pane launch path unchanged.

## Security and diagnostics

The server binds only to `127.0.0.1` on an ephemeral port. Requests require the
exact loopback host, an optional origin must match the loopback origin, and a
valid bearer token bound to an MCP session. Request bodies, responses,
concurrency, execution time, and sessions per credential are bounded. Session
replacement, deletion, pane teardown, and token revocation release both
transport and authorization state. Replacing a pane credential disconnects only
sessions bound to the replaced credential, so a cleanup task cannot close a
newly registered session. Requests return at the configured deadline;
cancelled Git operations terminate their subprocesses where possible.

Diagnostic responses are metadata-first, incrementally bounded, and redacted.
They do not expose
terminal content, harness output, secrets, environment values, or arbitrary
system logs. Trace and invariant files remain readable when Debug Mode is
disabled, but new durable capture is disabled; unified logs remain available.
Legacy top-level diagnostic files are reported separately from current
metadata-aware per-pane records.

## Development and troubleshooting

Use the Dev build for MCP protocol and UI validation:

```bash
make test-ui-dev
swift test --filter AgentControl
```

Dev state is isolated under
`~/Library/Application Support/agent-session-manager.dev/`. The final terminal
invocation contains only the selected harness command; setup, configuration,
and error reporting stay in the app layer.

