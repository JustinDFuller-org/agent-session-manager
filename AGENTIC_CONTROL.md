# Agentic Control

## Vision

Agent Session Manager should be bidirectional: it drives agent harnesses, and
agents can inspect and drive Agent Session Manager. An agent running in a pane
should be able to understand the current workspace and perform the same
meaningful session-management operations available to a user, while preserving
the app's existing lifecycle, persistence, worktree, focus, notification, and
terminal-purity behavior.

The control surface should be an app capability, not a collection of harness-
specific shell commands. The app remains the authority over tabs, panes,
profiles, worktrees, settings, status lines, and notifications.

## Research conclusion

MCP is the preferred agent-facing protocol. Claude Code, Cursor, Codex, and
OpenCode all support HTTP-based MCP integrations, and MCP standardizes server
discovery, resources, tools, structured results, and errors.

- [MCP transports](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [MCP tools](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)
- [Claude Code MCP](https://code.claude.com/docs/en/mcp)
- [Cursor MCP](https://docs.cursor.com/context/model-context-protocol)
- [Codex MCP](https://learn.chatgpt.com/docs/extend/mcp)
- [OpenCode MCP](https://dev.opencode.ai/docs/mcp-servers/)

Use one app-owned Streamable HTTP MCP server bound to `127.0.0.1`, rather than
one stdio server per pane. The app can then remain the single authority over
live `@MainActor` state and can issue per-pane credentials. Native XPC is a
possible future integration for other local clients, but the harnesses do not
speak XPC and would still require custom adapters.

The official [Swift MCP SDK](https://github.com/modelcontextprotocol/swift-sdk)
is the first implementation candidate. Its current Swift 6 requirements must
be checked against this repository's Swift 5.9 package settings before the
dependency is adopted. The control domain must remain independent of that
transport decision.

## Configuration

Agent control is configured like other user-facing behavior.

### Injection policy

Persist an `AgentControlInjectionPolicy` in a new app-settings file with these
user-facing choices:

- `Always`
- `Never`
- `Ask (on by default)`
- `Ask (off by default)`

The default is `Ask (on by default)`. When an ask policy is selected,
`NewPaneSheet` displays an Agent Session Manager control toggle using the
corresponding default. The final terminal command remains only the selected
harness command; Swift prepares any MCP configuration and environment before
the process starts.

Persist the resolved per-pane injection decision with session state. Changing
the global policy affects new, restored, and restarted pane launches. Already-
running harness processes require a restart before their environment can
change.

### Scope policy

Persist an `AgentControlScope` with these choices:

- `Pane` — the injected agent can access only its own pane.
- `Tab` — the injected agent can access all panes in its tab.
- `Global` — the injected agent can access the entire app.

The default is `Pane`. Scope is enforced for every read and write request, not
just communicated through tool descriptions.

There is no additional Agent Session Manager confirmation dialog for an
authorized MCP mutation. The injection policy controls whether the server is
available; it is not a per-tool approval mechanism. Harness-native MCP
approval behavior remains independent.

## Expected control surface

Expose reads primarily as MCP resources and changes as narrowly scoped tools.
Use stable IDs for addressing; names are display values only.

### Tabs and panes

- Create, inspect, focus, delete, and reorder tabs.
- Create panes with harness, profile, CLI options, environment values,
  worktree reference, base reference, priority, and control-injection choices.
- Inspect, focus, restart, delete, and reorder panes.
- Require explicit worktree-management and cleanup choices when an existing
  app policy would otherwise display an `ask` dialog.
- Preserve existing setup states, worktree ownership, cleanup behavior,
  notification cleanup, active IDs, and session persistence.

### Profiles and harness settings

- Create, inspect, edit, delete, and reorder profiles.
- Enable or disable harnesses for future pane creation.
- Enable harness options and update their default values.
- Update preset choices and multi-value option choices.
- Validate options against the selected harness catalog.
- Redact profile environment-variable values in read resources.

### Status lines and notifications

- Read status-line configuration and current structured status data for panes.
- Update global and profile-specific status-line configuration.
- List notifications with their tab and pane targets.
- Acknowledge a notification atomically by navigating to its pane and removing
  the notification through the same app path used by the UI.

The roadmap should maintain a feature-parity matrix for later capabilities,
including continue-on-restart, focus mode, activity state, PR tracking,
worktree policies, diagnostics, and observability.

## Proposed architecture

### Control service

Add an app-owned control service responsible for:

- Starting the localhost listener before any injected pane can launch.
- MCP initialization, resource discovery, tool discovery, and tool calls.
- One high-entropy bearer token per injected pane.
- Mapping tokens to source pane and configured scope.
- Origin validation, request limits, timeouts, cancellation, and token revocation.
- Structured audit events with secrets and bearer tokens redacted.

Network handlers should validate and decode requests, then dispatch to a
main-actor command router. The router should operate on existing
`AppState`/`AppSettings`/`Tab`/`Pane`/`Profile` behavior rather than duplicating
UI mutations or bypassing existing side effects.

Expose Codable snapshots and operation results instead of observable model
objects. A snapshot should include current IDs, names, harnesses, worktree
metadata, setup/activity state, profiles, option catalogs, status data, and
notifications, subject to the caller's scope.

### Harness adapters

Each adapter must generate app-owned configuration without overwriting user or
repository configuration:

- Claude Code: use its supported MCP configuration mechanism.
- OpenCode: merge an app-owned remote MCP configuration with existing config.
- Codex: use its supported HTTP MCP configuration and bearer-token settings.
- Cursor: resolve the documented project/global configuration limitation and
  provide a per-pane strategy; never overwrite tracked or user-owned
  `.cursor/mcp.json`.

If injection is requested and an adapter cannot prepare valid configuration,
the pane setup must report an actionable error instead of silently claiming
that agent control is active. `Never` or a declined ask choice must leave the
normal pane launch path unaffected.

## Implementation roadmap

Each item is intended to be a separate implementation session.

1. **Document and feasibility spike**
   - Keep this roadmap current.
   - Test the Swift MCP SDK against the repository toolchain.
   - Validate Streamable HTTP with a local MCP client.
   - Prototype configuration injection for every harness without repository or
     global-user configuration writes.

2. **Domain configuration and persistence**
   - Add injection-policy and scope types.
   - Add `AppSettings` and `SettingsPersistence` support.
   - Persist pane-level injection decisions in session state.
   - Add Settings and New Pane controls, accessibility identifiers, migration,
     and isolated Dev reset coverage.

3. **MCP lifecycle and security**
   - Implement the app-owned listener and service lifecycle.
   - Implement token registration, scope authorization, request validation,
     bounded output, cancellation, and revocation.
   - Add MCP protocol tests and runtime telemetry.

4. **Read-only resources**
   - Add scoped snapshots for tabs, panes, profiles, harness settings,
     status lines, and notifications.
   - Verify structured output, redaction, stale IDs, and scope boundaries.

5. **Harness injection**
   - Implement and test adapters one at a time, starting with Claude Code and
     OpenCode, followed by Codex and Cursor.
   - Verify that disabled or declined injection produces no MCP configuration.
   - Verify that enabled injection is prepared before process launch and does
     not print app plumbing in the terminal.

6. **Tab and pane mutations**
   - Add creation, deletion, focus, restart, and reordering tools.
   - Route worktree resolution and cleanup through existing app services.
   - Return explicit partial-failure results for multi-pane cleanup.

7. **Profiles and harness configuration**
   - Add profile CRUD and ordering tools.
   - Add harness enablement, option activation, defaults, preset choices, and
     multi-value choice tools.
   - Preserve custom options and redact sensitive values.

8. **Status lines and notifications**
   - Add status-line reads and updates for global and profile configuration.
   - Add notification listing and atomic acknowledge/navigation behavior.

9. **Parity, documentation, and hardening**
   - Audit every feature against the parity matrix.
   - Add the user-facing feature guide and feature skill.
   - Complete telemetry, failure handling, migration, security, and rollout
     documentation.

## Testing and acceptance

- Unit-test policy resolution, ask defaults, persisted state, scope checks,
  token mapping, DTOs, ordering, option validation, cleanup choices, and
  redaction.
- Protocol-test initialize, resource/tool discovery, successful calls,
  invalid IDs, unauthorized scope, expired tokens, malformed requests,
  cancellation, and output limits.
- Adapter-test all generated harness configuration while preserving existing
  configuration and avoiding repository pollution.
- Use a real MCP client against the isolated Dev app to create and mutate real
  tabs, panes, profiles, status-line settings, and notifications.
- Exercise the real New Pane flow for all four injection policies and verify
  the ask toggle defaults and overrides.
- Do not add fabricated state, test-only production branches, or fake
  screenshots. Run UI tests only with the approved Dev configuration.
- Add screenshot coverage for Settings and New Pane controls and inspect the
  generated artifacts before reporting visual verification.
- Load `instrument-runtime-telemetry` before implementing runtime behavior.
  Instrument server lifecycle, injection decisions, authentication,
  authorization, tool execution, failures, cancellation, and cleanup.

## Defaults and constraints

- Injection policy: `Ask (on by default)`.
- Scope: `Pane`.
- No extra Agent Session Manager confirmation for authorized MCP mutations.
- Tokens are runtime-only and never persisted or logged.
- Profile environment values are write-only or redacted in read resources.
- Policy changes affect future launches and restarts; existing harness
  processes must restart to receive changed MCP configuration.
- The app owns all setup work through Swift APIs; terminal panes receive only
  the final harness invocation.
