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
is the first implementation candidate. The repository uses Swift tools 6.1,
matching the SDK's current manifest requirement. The app source remains in its
existing Swift 5 language mode until its separate concurrency migration is
complete; it is still compiled by the installed Swift 6 toolchain. The control
domain must remain independent of that transport decision.

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

### Diagnostics and observability

Agents should be able to diagnose the pane or workspace they are operating in
without shelling out to inspect app-support files or asking a human to open a
dashboard. Expose diagnostics as scoped MCP resources and bounded query tools:

- Provide a diagnostic summary with app mode, build identity, Debug Mode state,
  active tab and pane IDs, and the scoped session metadata.
- Provide metadata-aware trace queries over current per-pane JSONL files, with
  pane or tab IDs, time windows, event-name filters, result limits, truncation,
  malformed-record, and legacy-file metadata. Read trace metadata rather than
  deriving identity from sanitized filenames.
- Provide invariant queries with occurrence IDs, invariant IDs, integrations,
  severity, timestamps, and bounded context. Preserve repeated occurrences as
  separate records.
- Provide unified-log queries over the Agent Session Manager process and
  subsystem, filtered by time, category, level, and event name. Normalize logs
  into a bounded, redacted result; never expose terminal content, harness
  output, secrets, environment values, or arbitrary system logs. The app may
  use `OSLogStore` for this read path, with date positions and matching
  predicates as the query primitives.
- Return availability and capture-state metadata when Debug Mode is disabled.
  Unified logs remain available because they are always on; existing trace and
  invariant files remain readable, but no new durable records are captured.

Pane scope may read only records attributable to its source pane. Tab scope may
read records attributable to panes in that tab. Unscoped global records and
cross-pane correlation are Global-scope data; they must not be returned to a
pane- or tab-scoped caller merely because they share a time window. Log
correlation must use safe structured IDs or an app-owned projection, never
parsing private message text.

Expose one narrowly scoped `debug.set_mode` tool for enabling or disabling
Debug Mode. It must persist through the existing debug settings path and reuse
the existing tracing and invariant reconfiguration behavior. Only a Global-
scope token may call it. File deletion, retention changes, path changes, and
diagnostic export are outside this first use-case.

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

## Prerequisite: Swift 6 language-mode migration

The Agentic Control implementation is gated on moving the repository to the
latest Swift language mode supported by the active Xcode toolchain. This is a
separate workstream from MCP and must land first so the control surface is not
built on a compatibility mode that we intend to remove.

Plan the migration as its own implementation session:

1. Change the SwiftPM package and generated Xcode targets to Swift 6 language
   mode while retaining the macOS 14 deployment target.
2. Build with the active release Xcode toolchain and inventory all new
   concurrency, isolation, Sendable, and framework-import diagnostics.
3. Migrate production code and tests in focused groups, preserving existing
   actor boundaries and adding explicit isolation or Sendable conformances
   only where they describe the real ownership model.
4. Run the complete unit, format, SwiftLint, Dev UI, and screenshot validation
   suite; separate pre-existing test failures from migration regressions.
5. Record the supported Xcode and Swift versions in the build documentation and
   CI so future toolchain updates remain intentional.

The prerequisite is complete when the package declares Swift 6 language mode,
the app and UI-test targets compile in that mode, all required validation is
green, and no compatibility-only compiler settings remain. Only then should
the MCP implementation roadmap continue with domain configuration and
persistence.

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

5. **Diagnostics and observability**
   - Add scoped diagnostic DTOs and resources for summaries, traces, invariants,
     and unified logs.
   - Reuse metadata-aware trace and invariant readers; keep legacy files
     separate and preserve truncation and malformed-record metadata.
   - Query only the Agent Session Manager process/subsystem through a bounded,
     redacted `OSLogStore` adapter; never expose terminal or harness output.
   - Add the Global-scope-only Debug Mode tool and reuse existing persistence
     and reconfiguration paths.
   - Protocol-test time windows, filtering, scope boundaries, redaction,
     disabled capture, cancellation, and output limits.

6. **Harness injection**
   - Implement and test adapters one at a time, starting with Claude Code and
     OpenCode, followed by Codex and Cursor.
   - Verify that disabled or declined injection produces no MCP configuration.
   - Verify that enabled injection is prepared before process launch and does
     not print app plumbing in the terminal.

7. **Tab and pane mutations**
   - Add creation, deletion, focus, restart, and reordering tools.
   - Route worktree resolution and cleanup through existing app services.
   - Return explicit partial-failure results for multi-pane cleanup.

8. **Profiles and harness configuration**
   - Add profile CRUD and ordering tools.
   - Add harness enablement, option activation, defaults, preset choices, and
     multi-value choice tools.
   - Preserve custom options and redact sensitive values.

9. **Status lines and notifications**
   - Add status-line reads and updates for global and profile configuration.
   - Add notification listing and atomic acknowledge/navigation behavior.

10. **Parity, documentation, and hardening**
   - Audit every feature against the parity matrix.
   - Add the user-facing feature guide and feature skill.
   - Complete telemetry, failure handling, migration, security, and rollout
     documentation.

### Feasibility spike record

The first implementation session is intentionally research-only. It must not
add an MCP dependency to the main package, add production control-service code,
change settings or session schemas, or write repository and global-user MCP
configuration. Temporary probes belong under an ignored temporary directory and
must remove their files, processes, and tokens before they finish.

#### Baseline captured on 2026-07-22

| Item | Observed value |
|---|---|
| Repository manifest | Swift tools 6.1, Swift 5 language mode, macOS 14 minimum |
| Host toolchain | Swift 6.4, Xcode 27.0 |
| Swift MCP SDK candidate | 0.12.1; its manifest declares Swift tools 6.1 |
| Claude Code | 2.1.216 |
| Codex | 0.144.6 |
| Cursor Agent | 2026.05.15-3f71873 |
| OpenCode | 1.18.4 |

The SDK candidate resolved and imported successfully in an isolated macOS 14
package using Swift tools 6.1 when compiled by the installed Swift 6.4
compiler. The repository now matches that requirement without adding the SDK
dependency yet. SwiftPM's tools version is a manifest compatibility floor; the
host's installed Swift 6.4 compiler remains the version used to build the
project. Enabling Swift 6 language mode is deferred because existing tracing
code currently reports sendability and actor-isolation errors under that mode.

#### Streamable HTTP result

The SDK's conformance server was started on `127.0.0.1:3001` at `/mcp`. The
[official MCP Inspector](https://github.com/modelcontextprotocol/inspector)
connected over Streamable HTTP and successfully completed:

- `initialize` and the initialized notification;
- `tools/list`;
- `resources/list`;
- `tools/call` for the harmless `add_numbers` fixture, returning `5`.

This validates the candidate transport and client path, including stateful
session creation, resource discovery, tool discovery, and a tool result. The
conformance fixture does not enforce the app's future per-pane bearer-token
policy, so authentication, token revocation, scope authorization, bounded
output, cancellation, and audit redaction remain gates for the lifecycle and
security phase. The MCP transport still requires loopback binding, Origin
validation, and authentication when used by the app; see the linked transport
specification above.

#### Harness injection findings

The supported configuration surfaces were confirmed from the installed CLI help
and official documentation without invoking commands that write user or
repository configuration:

| Harness | Candidate app-owned injection | Feasibility status |
|---|---|---|
| Claude Code | Pass a temporary JSON configuration through `--mcp-config`; compare normal loading with `--strict-mcp-config`. | Supported surface confirmed; isolated end-to-end loading remains part of adapter implementation. |
| OpenCode | Add a remote MCP entry through app-owned configuration content with a URL and HTTP header. | Supported remote-server shape confirmed; merge and precedence behavior must be tested before implementation. |
| Codex | Use Streamable HTTP `url` plus `bearer_token_env_var`, supplied through documented config or launch-time overrides. | Supported surface confirmed; exact per-pane preparation must avoid `~/.codex/config.toml` and project config writes. |
| Cursor | Current documentation exposes project `.cursor/mcp.json` and global `~/.cursor/mcp.json`; the installed Agent CLI exposes no per-pane MCP-config flag. | Isolation remains unresolved. Do not write either location; this harness may remain blocked until a documented per-pane strategy exists. |

The future adapter boundary is therefore documented but not implemented:
configuration preparation receives the pane identity, endpoint, runtime token,
working directory, and existing configuration context, then returns launch
arguments, environment additions, app-owned artifacts, cleanup ownership, or an
actionable unsupported-configuration error. Tokens remain runtime-only.

#### Exit criteria for this phase

This phase is complete when the SDK and local protocol evidence above is kept in
this roadmap, each harness has a recorded supported or blocked injection path,
and no probe has modified the repository or global-user configuration. Phase 2
may proceed with transport-agnostic policy and persistence types. Phase 3 must
not start the listener until the authentication, authorization, limits,
cancellation, revocation, and telemetry gates are implemented. Harness adapter
work remains ordered Claude Code, OpenCode, Codex, then Cursor.

## Testing and acceptance

- Unit-test policy resolution, ask defaults, persisted state, scope checks,
  token mapping, DTOs, ordering, option validation, cleanup choices, and
  redaction.
- Protocol-test initialize, resource/tool discovery, successful calls,
  invalid IDs, unauthorized scope, expired tokens, malformed requests,
  cancellation, and output limits.
- Protocol-test diagnostic summary, trace, invariant, and unified-log queries
  with pane/tab/global scope boundaries, time and event filters, redaction,
  truncation metadata, and Debug Mode disabled.
- Verify that only Global scope can enable or disable Debug Mode and that the
  operation persists and reconfigures existing diagnostic writers.
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
- Debugging reads are available at the caller's configured scope; unscoped
  global records and Debug Mode mutation require `Global` scope.
- The first debugging mutation is `debug.set_mode`; clearing, retention,
  path-management, and export operations are deferred.
- No extra Agent Session Manager confirmation for authorized MCP mutations.
- Tokens are runtime-only and never persisted or logged.
- Profile environment values are write-only or redacted in read resources.
- Policy changes affect future launches and restarts; existing harness
  processes must restart to receive changed MCP configuration.
- The app owns all setup work through Swift APIs; terminal panes receive only
  the final harness invocation.
