# OpenCode Harness Support Plan

This document is a working plan for adding [OpenCode](https://opencode.ai) as a fourth agent harness in Agent Session Manager, alongside Claude Code, Codex, and Cursor. It captures what has been researched so far, the architectural decisions already made, the remaining open questions, and a proposed implementation order. It is intentionally not polished end-user documentation; the user-facing feature doc will be created later at `documentation/features/opencode-cli.md`.

## Progress

Legend: `[ ]` not started, `[~]` in progress, `[x]` complete.

### Implementation phases

| # | Phase | Status | Notes |
|---|---|---|---|
| 0 | [API spike](#phase-0-api-spike) | [x] | Findings appended below in [Spike Findings](#spike-findings). Chip matrix and provider strategy are now locked. |
| 1 | [Enum + detection](#1-harness-enum-and-detection) | [x] | Enum case added; detection, onboarding toggle, persistence stubs, and compiler-required switch arms landed. |
| 2 | [CLI flag catalog + persistence](#3-cli-flags) | [x] | `CLIOptionConfig.opencodeAll` catalog in place with all OpenCode TUI flags (`--continue`, `--session`, `--fork`, `--prompt`, `--model`, `--agent`, `--auto`, `--port`, `--hostname`, `--mdns`, `--mdns-domain`, `--cors`). `recommendedDefaults(for: .opencode)` recommends `--model` only. `AppSettings.opencodeCliOptions` + `SettingsPersistence` save/load/merge wired through `opencode-settings.json`. Env-var catalog (`EnvVarConfig.opencodeAll`) stood up as new harness-keyed infrastructure with `OPENCODE_CONFIG_CONTENT`/`OPENCODE_PERMISSION` excluded as app-controlled. `AppSettings.opencodeEnvVarOptions` saved/loaded via `opencode-env-var-settings.json`. `extraEnvVars` plumbed through all harness arms via shared `applyExtraEnvVars` helper. Env-var editor surfaced in `NewPaneSheet`, `SettingsView`, `OnboardingWizardView`, and `ProfileSettingsViews`. Harness-aware `CLIOptionConfig` decode via `JSONDecoder.userInfo` so colliding `--agent`/`--continue`/`--model` IDs resolve the correct harness template (combined-search fallback preserved for legacy callers). |
| 3 | [Command builder + launch](#3-cli-flags) | [x] | `Tab.buildOpenCodeCommand(port:extraArgs:)` emits `opencode --hostname 127.0.0.1 --mdns=false[ --port <port>]<extraArgs>`. `FreePortAllocator` binds `NWListener` on port 0 to allocate a transient localhost port. All four launch sites (`addPane`, `completeSetup`, `refreshPane` Branch A, `refreshPane` Branch B) allocate a fresh port, rebuild the command, and inject `AGENT_SESSION_MANAGER_PANE_ID`, `AGENT_SESSION_MANAGER_OPENCODE_PORT`, and `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true`. Port allocation failure emits `opencode.port_allocation.failed` and omits `--port` so OpenCode falls back to a random port. `opencodePort` is stored transiently on `Pane` (not persisted). |
| 4 | [Config injection (`OPENCODE_CONFIG_CONTENT`)](#6-modifying-opencode-inputs-to-work-well-with-agent-session-manager) | [x] | `Tab.buildOpenCodeConfigContent()` emits compact JSON `{"share":"manual","autoupdate":false}`; `configureOpenCodeController` injects it as `OPENCODE_CONFIG_CONTENT` for all four launch sites, emits `opencode.config_content.injected` span, and reports `opencode.config_content.app_controlled` invariant when user-provided `OPENCODE_CONFIG_CONTENT`/`OPENCODE_PERMISSION` would be silently overridden. `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM` stays a separate env var because it is an env var, not a documented config key. Tests cover JSON shape, injection through `addPane`/`refreshPane`/`completeSetup`, and invariant behavior. |
| 5 | [Status provider](#7-status-line-support) | [ ] | |
| 6 | [Notifications](#8-notifications-and-attention) | [ ] | |
| 7 | [Restore + continue](#9-session-persistence-restore-and-continue-on-restart) | [ ] | |
| 8 | [Telemetry + invariants](#10-additional-cross-cutting-concerns) | [ ] | |
| 9 | [Docs + skill](#10-additional-cross-cutting-concerns) | [ ] | |

### Open questions

| # | Question | Status | Resolution |
|---|---|---|---|
| 1 | Random-port discovery | [x] | Always pin `--port`; stdout URL emission is undocumented and the TUI defaults to a random port. |
| 2 | SSE vs polling | [x] | SSE `GET /event` works but **requires `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true`**. Without the flag only `server.connected` is emitted. Fallback is polling `GET /session/:id`, not `/session/status` (the latter returns `{}` in 1.17.13). Inject the flag per-pane via `OPENCODE_CONFIG_CONTENT`. |
| 3 | Background subagent idle behavior | [x] | Background subagents create **child sessions** (`parentID` points to the parent). The bound parent session's `session.idle` fires accurately when its own turn completes, so no Claude-style `SubagentStop` gating is needed for v1. |
| 4 | Auto session names | [x] | `POST /session {"title":"..."}` works against the embedded TUI server and returns a session `id`. Passing `--session <id>` rebinds the TUI to that session. v1 can auto-name with the `<tab>/<pane>` convention. |
| 5 | Env-var catalog scope | [x] | Add OpenCode env-var editor in v1. |
| 6 | `OPENCODE_CONFIG_CONTENT` limits | [x] | **16 KB passes** and **512 KB passes** when the env var is set directly. The only failure observed was at ~1 MB when passing the value through a shell, which hit `ARG_MAX`/`argument list too long` — an invocation-shell limit, not an OpenCode loader limit. Swift `Process.environment` / `setenv` should not hit this ceiling. |
| 7 | Cost data availability | [x] | **Yes.** `GET /session/:id` returns `cost: number` and `tokens: {input, output, reasoning, cache: {read, write}}`. These also appear in SSE `session.updated` events. `inputTokens`/`outputTokens` and `cost` chips are supported. |
| 8 | Rate limits | [x] | Not documented anywhere; chips → "No". |

## Decisions already made

| Area | Decision | Rationale |
|---|---|---|
| Activation | Enabled by default if detected during onboarding | OpenCode should be immediately available when it is on the user's PATH, instead of requiring a manual opt-in toggle like Codex/Cursor. |
| Config injection for Agent Session Manager-owned overrides | `OPENCODE_CONFIG_CONTENT` env var | Highest-precedence non-managed config source, terminal-pure (no shell prepending), and scoped per-pane without touching the user's worktree. |
| Status line strategy | HTTP server API | OpenCode already runs a per-TUI HTTP server with a documented REST/SSE surface. This is more robust than scraping files or installing a global plugin. |
| Notification kind | Distinct `.opencodeStop`; attention source `.opencodePermissionRequest` | Mirrors Claude's `.claudeStop` `NotificationKind` and `claudePermissionRequest` `PaneAttentionEvent.Source`. `NotificationKind` has no permission analog today. |
| Port on restart | Re-allocate fresh each launch | Avoids bind collisions; rebuild `--port` and `OPENCODE_CONFIG_CONTENT` on every launch. |
| Env-var editor | Build harness-keyed env-var stack in v1 | Parameterize `EnvVarConfig.recommendedDefaults(for:)` and plumb `extraEnvVars` through **all** harness arms in `Tab.addPane`/`refreshPane`/`completeSetup` (today only `.claude` injects them). |
| Network binding | Pin `--hostname 127.0.0.1` and `--mdns=false` per pane | Avoid advertising unauthenticated per-pane HTTP servers on the LAN; ephemeral localhost ports are sufficient. |
| Server auth | Defer `OPENCODE_SERVER_PASSWORD` to post-v1 | Accepted risk because each pane binds `127.0.0.1` on an OS-allocated ephemeral port. Documented assumption so future sandboxing changes don't widen exposure. |
| No programmatic TUI driving | Forbid `/tui/submit-prompt`, `/tui/append-prompt`, `/tui/execute-command`, `/tui/show-toast` | Terminal Purity already forbids app-driven setup; extend the rule to OpenCode's HTTP surface. |
| Env-var namespace | Spike must confirm OpenCode ignores unknown `OPENCODE_*` vars; otherwise use a non-`OPENCODE_` prefix | OpenCode parses `OPENCODE_*` env vars as config; `AGENT_SESSION_MANAGER_OPENCODE_PORT` is a footgun if unknown prefixed keys are treated as config. |

## Phase 0: API spike

Before finalizing the status-line chip matrix or the notification provider, we need the actual server schema. The public docs name the types (`Session`, `SessionStatus`, `Message`, `Part`) but do not inline field names or types.

### Work to do

1. Install or locate the `opencode` binary.
2. Launch a headless server: `opencode serve --port 4096`.
3. **Locate the OpenAPI specification endpoint.** Per the live server docs, `GET /doc` returns an HTML page (Swagger UI), not parseable JSON. Try `Accept: application/json` on `/doc`, or probe `/doc.json` / `/openapi.json`. Fallback: read `packages/sdk/js/src/gen/types.gen.ts` directly from the OpenCode repo for the schema.
4. Optional: read `packages/sdk/js/src/gen/types.gen.ts` from the OpenCode repository for cross-reference.
5. **Hit `GET /global/health`** — expect `{healthy: true, version: string}`. Prefer this over `opencode --version` stdout for the `version` status chip and for `detectedHarnessVersion` injected into `StatusProviderContext`.
6. Subscribe to `GET /event` (SSE) and observe payload shapes for at least:
   - `server.connected`
   - `session.created`
   - `session.updated`
   - `session.idle`
   - `session.status`
   - `permission.asked`
   - `permission.replied`
   - `tool.execute.before` / `tool.execute.after`
   - Confirm whether `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM` must be set for the stream to work.
7. **Confirm `POST /session {title?}` works against the embedded TUI server** (the server started by `opencode [project]`, not only `opencode serve`). If it does, v1 can auto-name OpenCode panes at creation.
8. Confirm presence/absence of these fields on `Session` / `SessionStatus` / `Message`:
   - `model`
   - `title`
   - `inputTokens` / `outputTokens`
   - `context` / `contextRemaining`
   - `cost`
9. **Stress-test `OPENCODE_CONFIG_CONTENT` up to 8–16 KB** through macOS `setenv` + OpenCode's loader. Include representative injected keys (`permission`, `share`, `snapshot`, `autoupdate`, and a `model` override).
10. **Subscribe to `GET /event` for at least 60 seconds** and observe whether the URLSession streaming connection drops under macOS sandbox / quarantine quirks. Document failure modes (silent disconnect, backpressure, partial events).
11. Create a one-page findings note (can live in this doc or a scratch file under `/tmp`) that drives the final chip matrix and provider design.

### Outcomes

- Finalize whether `cost`, `inputTokens`, `outputTokens`, `context`, `contextRemaining`, and `sessionName` chips are supported for OpenCode.
- Determine whether `session.idle` fires while `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS` tasks are still running, whether the `OPENCODE_EXPERIMENTAL` umbrella flag is required, and what event (if any) can gate it.
- Lock the `OpenCodeStatusProvider` polling/SSE strategy and confirm whether SSE requires the experimental event-system flag.
- Choose the session-binding strategy: `POST /session {title?}` upfront + `--session <id>`, or discover-from-status fallback.

## OpenCode architecture primer

OpenCode differs from the existing harnesses in one crucial way: the CLI is both a TUI and an HTTP server.

- Running `opencode [project]` launches the TUI *and* a local HTTP server. The TUI is a client of that server.
- Running `opencode serve` launches a headless server only.
- The server exposes an OpenAPI 3.1 spec and publishes endpoints such as:
  - `GET /session` — list sessions
  - `GET /session/status` — status map for all sessions
  - `GET /session/:id` — session details
  - `GET /session/:id/message` — messages
  - `GET /event` — server-sent events stream
  - `POST /tui/append-prompt`, `POST /tui/submit-prompt` — drive the TUI
- Config precedence (later overrides earlier):
  1. Remote `.well-known/opencode`
  2. Global `~/.config/opencode/opencode.json`
  3. `OPENCODE_CONFIG` env var
  4. Project `opencode.json`
  5. `.opencode/` directories
  6. **`OPENCODE_CONFIG_CONTENT` env var**
  7. Managed settings
- The hook analog is JS/TS plugins placed in `.opencode/plugins/` or `~/.config/opencode/plugins/`, or listed in the `plugin` config key. Relevant plugin events include `session.created`, `session.updated`, `session.idle`, `permission.asked`, `permission.replied`, `message.updated`, `tool.execute.before/after`, `shell.env`.

Sources: [OpenCode Config docs](https://opencode.ai/docs/config/), [CLI docs](https://opencode.ai/docs/cli/), [Server docs](https://opencode.ai/docs/server/), [Plugins docs](https://opencode.ai/docs/plugins/).

## 1. Harness enum and detection

### Work to do

- Add `case opencode` to `Harness` in `Sources/AgentSessionManager/Models/Pane.swift`.
  - `displayName`: "OpenCode"
  - `commandDescription`: "opencode" (the binary name). `ToolAgnosticDataProvider` already accepts a `toolCommand: String` and will work as-is for OpenCode's baseline facts.
- Update `Pane.swift:16` (`static var allCases: [Harness] { [.claude, .codex, .cursor] }`) to include `.opencode`. That override is where the `.shell` exclusion lives.
- `HarnessDetector.detectInstalled(shell:)` already probes `tool.commandDescription` with `which <cmd>`, so OpenCode detection is automatic once the enum case exists.
- Onboarding `OnboardingWizardView.toolsStep` iterates `Harness.allCases`, so OpenCode will appear in the detection list without extra view work.
- Update `StatusLineConfig.allHarnesses` and any capability sets that currently read `[.claude, .codex, .cursor]`.
- Update compiler-enforced `switch` arms that key on `Harness`. **Every switch already includes a `.shell` arm** (`Pane.swift:9-13` declares four cases); `.opencode` must be added alongside it. Known sites:
  - `Pane.swift:18-25, 27-34` (`displayName`, `commandDescription` — 4 arms)
  - `CLIOptionConfig.swift:34-63, 419-442` (decoder template lookup, `recommendedDefaults` — 4 arms)
  - `Tab.swift:519-549, 591-635, 951-981` (`addPane`, `refreshPane`, `completeSetup` — 4-arm switches)
  - `Tab.swift:656-679` (bare restart path — uses `if pane.harness == .claude/.cursor/.codex` checks, **not** a switch; add a fourth `.opencode` branch)
  - `OnboardingWizardView.swift:483-495` (CLI flag save — 4-arm switch)
  - `SettingsView.swift:523-558` (settings CLI options — 4-arm switch)
  - `NewPaneSheet.swift:30-35` (`activeOptions` — 4-arm switch)
  - `ProfileSettingsViews.swift:181-186, 287-313` (`activeOptions`, `onAddToGlobal` — 4-arm switches)
  - `StatusLineMonitor.swift:103-117, 119-149` (providerContext build, provider selection)
- Update tests that exercise `Harness.allCases`:
  - `Tests/CLIOptionConfigTests.swift:519` asserts `count == 3` — bump to `4` and add `XCTAssertTrue(Harness.allCases.contains(.opencode))`.
  - `Tests/PlainTerminalAccessTests.swift:21-25` does **not** assert a count; it only asserts `.contains` for the three user-facing cases. Add `.contains(.opencode)`; no count bump needed.

### Decision note

OpenCode is enabled by default when detected. This means `appSettings.activeTools` should include `"opencode"` after onboarding if `HarnessDetector` finds it. The onboarding "Continue" button already loops `checkedTools` and calls `setActive(_:true)`, so the only change is defaulting the toggle to on when detected.

## 2. Onboarding

### Work to do

- Ensure the OpenCode toggle in the tools step is checked by default when detected.
- In `OnboardingWizardView.cliFlagsStep`, seed `draftCliOptions[.opencode]` with `CLIOptionConfig.recommendedDefaults(for: .opencode)` when OpenCode is in `checkedTools`.
- Seed `draftEnvVarOptions[.opencode]` with `EnvVarConfig.recommendedDefaults(for: .opencode)` once the harness-keyed env-var API from §4 exists.
- Save OpenCode CLI options during onboarding using a new `SettingsPersistence.saveOpenCodeOptions(appSettings:)` call.
- Save OpenCode env-var options using a new `SettingsPersistence.saveOpenCodeEnvVars(appSettings:)` call. **There is no Codex/Cursor env-var persistence to mirror** — today `AppSettings` has only one env-var field (`envVarOptions`, Claude-only). This is the first harness-keyed env-var persistence; the upstream catalog work is described in §4.
- **Note:** `OnboardingWizardView.swift:497-499` today persists env vars only when `.claude` is in `toolsToSave`. Extending this to OpenCode requires adding an analogous block conditioned on `.opencode in toolsToSave`.

## 3. CLI flags

### Catalog

OpenCode TUI/global flags that matter for Agent Session Manager (from the CLI docs):

| Flag | Short | Type | Description |
|---|---|---|---|
| `--continue` | `-c` | boolean | Continue the last session |
| `--session` | `-s` | string | Session ID to continue |
| `--fork` | | boolean | Fork the session when continuing |
| `--prompt` | | string | Prompt to use |
| `--model` | `-m` | string | Model to use (`provider/model`) |
| `--agent` | | string | Agent to use |
| `--auto` | | boolean | Auto-approve permissions not explicitly denied |
| `--port` | | string/number | Port for the local server |
| `--hostname` | | string | Hostname for the local server |
| `--mdns` | | boolean | Enable mDNS discovery |
| `--mdns-domain` | | string | Custom mDNS domain name |
| `--cors` | | string | Additional browser origin(s) for CORS |

### Work to do

- Add `CLIOptionConfig.opencodeAll: [CLIOptionConfig]` with the flags above.
- Add the `.opencode` case to `CLIOptionConfig.recommendedDefaults(for:)`.
- Add `.opencode` cases to `optionType` for boolean vs string mapping.
- Add `opencodeCliOptions: [CLIOptionConfig]` to `AppSettings`.
- Add `SettingsPersistence` methods to load/save OpenCode options (mirror `saveCodexOptions` / `saveCursorOptions`).
- Add `Tab.buildOpenCodeCommand(port:extraArgs:)` that emits only the final invocation, e.g. `opencode --port 12345 --hostname 127.0.0.1 --mdns=false --continue`.
- Wire `.opencode` into `Tab.addPane`/`completeSetup`/`refreshPane`/`restartPane`.
- Respect Terminal Purity: no setup commands in the terminal string; `--port`, `--hostname`, `--mdns`, and other injected flags are computed in Swift and appended to the final command.

### Network binding defaults

Per-pane invocations must default `--hostname 127.0.0.1` and `--mdns=false`. `--mdns` and `--mdns-domain` stay in the flag catalog for advanced users but are disabled in `recommendedDefaults`. Rationale: without a per-pane `OPENCODE_SERVER_PASSWORD`, mDNS would advertise unauthenticated per-pane HTTP servers on the LAN. Defaulting to localhost + ephemeral port + mDNS-off is the safe baseline.

### Server auth threat model

v1 does not auto-set `OPENCODE_SERVER_PASSWORD`. Accepted risk: each pane binds to `127.0.0.1` on an OS-allocated ephemeral port, so only local processes can reach it. If a later change moves the server to a non-loopback bind or a fixed port, re-open this decision — without auth that change would expose the agent to the network.

### Permission precedence note

The `--auto` CLI flag and the `permission` JSON key injected via `OPENCODE_CONFIG_CONTENT` both affect auto-approve behavior. Per the precedence table, `OPENCODE_CONFIG_CONTENT` (tier 6) wins over the `OPENCODE_PERMISSION` env var. The CLI flag's relationship to env-injected config isn't documented. §6's injected `permission` defaults will take effect over user-set `OPENCODE_PERMISSION`; the env-var editor in §4 must surface this so the user doesn't think their `OPENCODE_PERMISSION` value is effective.

### Important note on `--port`

The status-line provider needs to know which server belongs to the pane. The reliable approach is to allocate a free port in Swift (bind-and-release a socket) and pass it via `--port`. Each OpenCode pane therefore runs on its own predictable port, which also matches the per-pane isolation model. A random-port default would require discovering the port from OpenCode stdout or a known file; stdout URL emission is undocumented, so random-port discovery is not a viable primary strategy.

## 4. CLI environment variables

OpenCode exposes many `OPENCODE_*` env vars. Relevant categories for the settings sheet:

- Config path: `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `OPENCODE_TUI_CONFIG`, `OPENCODE_CONFIG_CONTENT`
- Server auth: `OPENCODE_SERVER_PASSWORD`, `OPENCODE_SERVER_USERNAME`
- Behavior: `OPENCODE_AUTO_SHARE`, `OPENCODE_DISABLE_AUTOUPDATE`, `OPENCODE_DISABLE_TERMINAL_TITLE`, `OPENCODE_DISABLE_AUTOCOMPACT`, `OPENCODE_DISABLE_MOUSE`, `OPENCODE_PERMISSION`
- Claude-code interop: `OPENCODE_DISABLE_CLAUDE_CODE`, `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT`, `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS`
- Models / network: `OPENCODE_DISABLE_MODELS_FETCH`, `OPENCODE_MODELS_URL`
- LSP / tools: `OPENCODE_DISABLE_LSP_DOWNLOAD`
- Dev/prod isolation: `OPENCODE_DISABLE_DEFAULT_PLUGINS`
- Restore-related: `OPENCODE_DISABLE_PRUNE`
- Telemetry: `OPENCODE_CLIENT` (suggest `"agent-session-manager"`)
- Testing: `OPENCODE_FAKE_VCS`
- Experimental: `OPENCODE_EXPERIMENTAL`, `OPENCODE_EXPERIMENTAL_*`, `OPENCODE_ENABLE_EXPERIMENTAL_MODELS`, etc.

### Scope clarification

Today `EnvVarConfig` has a single Claude-only catalog (`EnvVarConfig.all`, all entries are `ANTHROPIC_*`/`CLAUDE_CODE_*`) and a `recommendedDefaults()` function that takes **no parameter**. There are no `codexAll`/`cursorAll` env-var catalogs and no harness-keyed `AppSettings` env-var fields besides `envVarOptions` (Claude-only). Standing up OpenCode env-var support is **new harness-keyed infrastructure**, not a port of an existing Codex/Cursor env-var pattern.

### Recommended API shape

Mirror `CLIOptionConfig.recommendedDefaults(for: Harness)`:
- Parameterize `EnvVarConfig.recommendedDefaults(for cli: Harness)`.
- Keep `EnvVarConfig.all` as the Claude-only catalog (fed to the `.claude` arm).
- Add `EnvVarConfig.opencodeAll: [EnvVarConfig]` as the OpenCode catalog (fed to the `.opencode` arm).
- Keep the parameterless `recommendedDefaults()` as a thin wrapper calling `recommendedDefaults(for: .claude)` to avoid churning existing call sites (or migrate them — pick during implementation).
- Add `AppSettings.opencodeEnvVarOptions: [EnvVarConfig]` defaulting to `EnvVarConfig.opencodeAll`.

### Conflict resolution

Per the precedence table, `OPENCODE_CONFIG_CONTENT` (tier 6) wins over `OPENCODE_PERMISSION` (env var). Because Agent Session Manager injects `OPENCODE_CONFIG_CONTENT` per-pane (§6), any user-set `OPENCODE_PERMISSION` is silently overridden.

**Recommended editor behavior:**
- Remove `OPENCODE_PERMISSION` from the user-facing env-var sheet entirely (it's effectively read-only from the user's perspective), OR
- Surface it with an "overridden by app-injected config" caption and disable the text field.

Never present it as editable — that would silently misrepresent the effective permission policy.

### Work to do

- Create `EnvVarConfig.opencodeAll` catalog populated with the OpenCode env vars listed above.
- Add `EnvVarConfig.recommendedDefaults(for cli: Harness)` with a `.opencode` arm returning recommended IDs (e.g., `OPENCODE_AUTO_SHARE`, `OPENCODE_DISABLE_AUTOUPDATE`, `OPENCODE_CLIENT`, `OPENCODE_DISABLE_DEFAULT_PLUGINS`).
- Add `opencodeEnvVarOptions: [EnvVarConfig]` to `AppSettings` (near `cliOptions`/`codexCliOptions`/`cursorCliOptions`).
- Add `SettingsPersistence` methods to load/save OpenCode env vars.
- Update `OnboardingWizardView.cliFlagsStep` to show a harness-keyed env-var editor when OpenCode is selected, and extend the save condition at `OnboardingWizardView.swift:497-499` to also save when `.opencode` is in `toolsToSave`.
- Update `Tab.addPane`, `Tab.refreshPane`, and `Tab.completeSetup` so `extraEnvVars` are injected for **all** harnesses, not only `.claude` (today `Tab.swift:523-527`, `601-605`, and `955-958` are Claude-only). This is required for profiles and env-var editor parity.
- Reserve `OPENCODE_CONFIG_CONTENT` for internal use in §6; it should not be editable in the user-facing env-var sheet, because Agent Session Manager will write it itself.

## 5. Profile creation

### Work to do

- `Profile.harness` is already a `Harness`, so `.opencode` profiles require no model changes.
- `ProfileCLIOption` IDs will be drawn from `CLIOptionConfig.opencodeAll`.
- `ProfileEnvVar` IDs will be drawn from `EnvVarConfig.opencodeAll` — that catalog must exist first; see §4 for the upstream work and its new-infrastructure note.
- Ensure `ProfileSettingsViews` and `StatusLineConfig` pickers treat `.opencode` as a first-class harness.
  - `StatusLineConfig.allHarnesses` (line 142) is `[.claude, .codex, .cursor]` today — OpenCode must be added there too. Adding `.opencode` automatically extends `appCapability`, `mergedCapability`, and `modelCapability` chips to OpenCode; `claudeCapability`/`claudeCodexCapability` chips remain OpenCode-ineligible unless explicitly extended (which §7.5 already accounts for).
  - `ProfileSettingsViews.swift:193-195` (`hiddenEnvVars`) today reads only `appSettings.envVarOptions` (Claude-only). Extending to OpenCode requires the harness-keyed env-var stack (§4) to be in place; otherwise the hidden-state UI will misreport available env vars.
- Add OpenCode to the recommended-defaults flow when creating a profile for the first time.

## 6. Modifying OpenCode inputs to work well with Agent Session Manager

This is the analog of Claude Code's temp `settings.json` with `statusLine` + lifecycle hooks, or Codex's `-c hooks.*` hook injection.

### Recommended approach: `OPENCODE_CONFIG_CONTENT`

Agent Session Manager will write a small inline JSON config into the `OPENCODE_CONFIG_CONTENT` environment variable for each pane. This config sits at the second-highest precedence tier, so it can override global/user/project OpenCode config without modifying files in the worktree.

Suggested contents to inject per pane:

- `permission`: set safe defaults or pass through user preference.
- `share`: set to `"manual"` or `"disabled"` to avoid accidental sharing of work-in-progress sessions.
- `snapshot`: respect user preference; consider defaulting based on worktree cleanup behavior.
- `autoupdate`: optionally disable to prevent update prompts inside a pane.
- Any other config-only overrides that improve the embedded-terminal experience.

What `OPENCODE_CONFIG_CONTENT` cannot do:

- It cannot install a plugin or hook script. Plugins require a file on disk in `.opencode/plugins/` or `~/.config/opencode/plugins/` (or a `plugin` array referencing npm packages, which would trigger a `bun install` at startup — a Terminal Purity concern).
- It cannot reference per-pane temp files inside JSON (unless we use env-var substitution, which OpenCode supports via `{env:VAR}`).
- It cannot exceed the macOS `setenv` / `ARG_MAX` payload budget. The 8–16 KB stress test in Phase 0 must confirm the size headroom (reopened Q6).

Therefore status-line/attention hooks should use the HTTP server API (§7) rather than a plugin. If the server API proves insufficient for attention notifications, a one-time global plugin install is the fallback, but it is deprioritized because it affects the user's real OpenCode setup and violates the dev/prod isolation goal.

### Work to do

- Create a helper that builds the per-pane inline JSON config.
- Inject it into `controller.pendingEnvironment` as `OPENCODE_CONFIG_CONTENT=<json>`.
- **Conflict behavior:** because Agent Session Manager injects `OPENCODE_CONFIG_CONTENT` per-pane, any user-provided `OPENCODE_CONFIG_CONTENT` or `OPENCODE_PERMISSION` value is overridden. The env-var editor (§4) must surface this; the UI must not present these keys as editable.

## 7. Status line support

This is the largest integration surface. The plan is to connect to each pane's OpenCode server and read live session data.

### 7.1 Per-pane port allocation

Each `opencode` TUI starts its own server. Agent Session Manager must ensure each pane's server is reachable.

- Allocate a free port in Swift before launching the pane (bind a temporary socket, read the port, close it, pass `--port <port>` to OpenCode). Use `Network.NWListener` on port 0 as the idiomatic approach; no free-port allocator exists in the codebase today.
- **TOCTOU caveat:** bind-and-release has a race window before OpenCode rebinds the port. Two mitigations:
  - **Preferred:** keep the `NWListener` socket bound until OpenCode has forked and is listening (idiomatic via `NWListener` + `accept` on a child path).
  - **Acceptable fallback:** release the port, spawn OpenCode with `--port`, then hit `GET /global/health` with exponential backoff. If the bind fails, reallocate a fresh port and respawn.
  The Phase 0 spike should pick one and document it.
- Store the allocated port with the pane controller / `StatusProviderContext` so the status provider can connect.
- On restore, reallocate a fresh port and relaunch OpenCode on that port; OpenCode session state is preserved via `--session <id>` or `--continue`.
- Collision risk exists across dev/prod builds because ports are OS-wide; re-allocating a fresh port on every launch mitigates this.

### 7.2 Session binding

A single pane/server may host multiple sessions over time. The provider needs to know which session is "the pane's session."

**Chosen strategy:** `POST /session {title?}` upfront, then pass `--session <id>` to the OpenCode CLI.
- Before launching the pane, the app calls `POST /session {title: "<tab>/<pane>"}` on the per-pane server. If the embedded TUI server isn't reachable before the TUI starts, fall back to discovery (next bullet).
- The returned `sessionID` is passed to the TUI launch via `--session <id>`.
- The provider binds to that exact id; no heuristic matching.
- Store the bound `sessionID` on the pane so restore/restart rebinds to the same session.
- **Fallback (when `POST /session` isn't usable pre-launch):** launch the TUI, then call `GET /session` and pick the active/running session (or most-recently-updated). Avoid `GET /session/status`; it returned `{}` in 1.17.13 and carries no useful fields.
- **Auto session names:** because `POST /session {title?}` accepts a title at creation, OpenCode panes CAN be auto-named in v1 (no longer Claude-only as Q4 originally closed). The title format mirrors Claude's `<tab>/<pane>` convention.

### 7.3 `OpenCodeStatusProvider`

Create a new provider conforming to `StatusLineDataProvider`, modeled on `CodexStatusProvider`.

- Use `ToolAgnosticDataProvider` as the baseline for worktree, branch, duration, changed lines, version, and PR data. The OpenCode server offers some richer sources, but not for line counts:
  - `GET /session/:id/diff` returned `[]` for filesystem edits in the spike; do **not** use it for `linesAdded`/`linesRemoved`. Keep the app-owned `git diff --stat` baseline.
  - `GET /vcs` can augment branch detection (`{"branch","default_branch"}`), but app-owned git is still needed for line counts.
  - `GET /project/current` confirms the project root; note that OpenCode treats the main repo as the project root and the worktree as a `sandbox`.
- Resolve the OpenCode version from `GET /global/health` (`{healthy, version}`), not from parsing `opencode --version` stdout. Pass it into `StatusProviderContext` as `detectedHarnessVersion` and use an `OpenCodeVersionAdapter` (modeled on `CodexVersionAdapter`) to gate fields/endpoints by version.
- Start an SSE connection to `GET /event` against `http://127.0.0.1:<port>`; this requires `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true` injected per-pane (§6). Fall back to periodic polling of `GET /session/:id` at 15 s cadence if SSE lifecycle proves problematic in Swift concurrency. Do not rely on `GET /session/status`; it returned `{}` in 1.17.13.
- Parse responses from `GET /session/:id` (and SSE `session.updated` events) to populate:
  - `model` (`{id, providerID, variant}` object)
  - `inputTokens`, `outputTokens` (`tokens.input`, `tokens.output`)
  - `cost` (`cost: number`)
  - `version`
  - `sessionName` (from `title`, set at creation via `POST /session {title?}`)
- Do **not** populate `context` / `contextRemaining`; those fields are not exposed in 1.17.13.
- Merge baseline and harness data in `emitMerged()`, following the `CodexStatusProvider` pattern.
- Add bounded tracing for binding attempts, parse failures, field presence, version-drift detection, and SSE/polling transitions. Do not log prompts, messages, or auth data.

### 7.4 `StatusLineMonitor` wiring

- In `StatusLineMonitor.init`, add an `.opencode` branch that creates `OpenCodeStatusProvider`.
- Add `opencodePort: Int?` to `StatusProviderContext` (mirroring `codexHookRecordPath`).
- Ensure `detectedHarnessVersion` is populated from `/global/health` for the OpenCode arm.
- Inject environment variables into the pane:
  - `AGENT_SESSION_MANAGER_PANE_ID=<pane-id>` (consistent with Cursor/Codex)
  - `AGENT_SESSION_MANAGER_OPENCODE_PORT=<port>` (optional, for diagnostics/plugins) — **namespace risk:** OpenCode parses any `OPENCODE_*` env var as config. Spike must confirm unknown `OPENCODE_*` keys are ignored; otherwise rename to a non-`OPENCODE_`-prefixed env var (e.g., `AGENT_SESSION_MANAGER_OPN_PORT`).
  - `OPENCODE_CONFIG_CONTENT=<json>`
  - If SSE gating is confirmed: `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true`.
- Update `StatusLineConfig.itemCapabilities` so OpenCode-capable chips are selectable.

### 7.5 Chip capability classification

Proposed OpenCode support per chip (finalized after Phase 0 spike):

| Chip | Source | Initial target |
|---|---|---|
| `model` | `GET /session/:id` / SSE `session.updated` | Yes (object `{id, providerID, variant}`; display as `providerID/modelID`) |
| `inputTokens` | `GET /session/:id` / SSE `session.updated` | Yes (`tokens.input`) |
| `outputTokens` | `GET /session/:id` / SSE `session.updated` | Yes (`tokens.output`) |
| `context` / `contextRemaining` | Server API | No; not exposed on Session or SessionStatus in 1.17.13 |
| `cost` | `GET /session/:id` / SSE `session.updated` | Yes (`cost: number`) |
| `version` | `GET /global/health` | Yes (`version` string) |
| `sessionName` | `GET /session/:id` / SSE `session.updated` | Yes (set via `POST /session {title}` and pass `--session <id>`) |
| `duration` | App-owned | Yes |
| `worktree` | App-owned | Yes |
| `linesAdded` / `linesRemoved` | App-owned baseline (`git diff --stat`) | Yes; `GET /session/:id/diff` returned `[]` for filesystem edits, so do not use it for line counts |
| `pr` | App-level PR tracking | Yes |
| `profileName` | App state | Yes |
| `rate5h` / `rate7d` | Not documented | No |
| `effort` / `thinking` / `vimMode` / `agentName` / `outputStyle` / `exceeds200k` | Claude-specific | No |

## 8. Notifications and attention

OpenCode does not use the same hook file mechanism as Claude Code, but it exposes equivalent signals.

- `permission.asked` plugin event or server event corresponds to "needs user attention."
- `session.idle` corresponds to "the agent finished a turn."

### Naming correction

- The `PaneAttentionEvent.Source` enum today has `claudeStop`, `claudePermissionRequest` (not `claudePermission`), `claudeNotification`, `cursorStop`, `osc777`, `rawBell`. There is no `.claudePermission` source.
- The `NotificationKind` enum today has only `terminalBell`, `prMerged`, `claudeStop` — there is no permission kind. Permission events today route through `PaneAttentionEvent.Source.claudePermissionRequest`, not a separate `NotificationKind`.

Therefore:

- Add `PaneAttentionEvent.Source.opencodeStop` — mirrors `claudeStop`.
- Add `PaneAttentionEvent.Source.opencodePermissionRequest` (full spelling, mirrors `claudePermissionRequest`) — **not** a new `NotificationKind`.
- Add `NotificationKind.opencodeStop` — mirrors `claudeStop`.
- Permission events in v1 produce a `PaneAttentionEvent` (sidebar entry) but **not** a `NotificationKind` (no `.opencodePermission` notification) — match the existing Claude pattern. If you want a permission notification, open a separate decision.

### Subagent gating

The OpenCode flag that enables background subagents is `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS` (env var). The `OPENCODE_EXPERIMENTAL` umbrella flag may also need to be set for any experimental feature to take effect (Phase 0 confirms). Investigate whether `session.idle` fires prematurely while background subagents are running. If so, implement suppression logic analogous to Claude's `SubagentStop`/`PreToolUse` gating. The Phase 0 spike determines whether `tool.execute.before`/`tool.execute.after` can proxy for `PreToolUse`/`SubagentStop`.

If `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM` is required for SSE, the same env-injection flow (§6) must set it per-pane; otherwise `session.idle` and `permission.asked` events won't fire from `GET /event`.

### Work to do

- Consume attention/stopped signals from the server SSE stream (`GET /event`) inside `OpenCodeStatusProvider`.
- Map `session.idle` to `PaneNotification` / sidebar entries, similar to Claude's `Stop` hook.
- Map permission events to attention notifications via `PaneAttentionEvent.Source.opencodePermissionRequest`.
- Add `PaneAttentionEvent.Source.opencodeStop` and `NotificationKind.opencodeStop`.
- Add `NotificationConfig.isOpencodeStopNotificationEnabled` toggle, `CodingKey`, init/encode arm, and `AppSettings` field.
- Update `AppState.addNotification` source→kind mapping to handle `.opencodeStop`.

## 9. Session persistence, restore, and continue-on-restart

### Backward-compatibility warning

`PersistedPane.harness` is a `Harness` enum. The existing decoder at `SessionPersistence.swift:157` uses `decodeIfPresent(Harness.self, …) ?? .claude`. `decodeIfPresent` **throws** on an unrecognized raw value — the `??` only fires for a missing key, not for an unknown string. Once `.opencode` ships, any `sessions.json` written by the new build will throw when decoded by an older build (which lacks the enum case). Older builds will **not** silently fall back to `.claude`; they will crash the restore.

Mitigation options:

1. Accept breakage — document in release notes that opening v1 OpenCode sessions in an older build crashes restore; older builds must be upgraded.
2. Wrap the decode in a custom `init(from:)` that catches the throw and degrades to `.claude` with a bounded log, so older builds survive (but the pane launches as Claude, not OpenCode — confusing UX, must surface a banner).

Recommendation: option 1. Older builds crashing on a new file format is acceptable; option 2 silently masks the upgrade and risks users running a pane as Claude when they meant to run OpenCode.

### Session binding

Cross-link §7.2: the app pre-allocates a `sessionID` via `POST /session {title?}` and passes it via `--session <id>`. Persisted state for restore: pane id, `sessionID` (when continuing), injected-config snapshot. The port is transient and reallocated on relaunch — do not persist it. On restore, reallocate a fresh port, rebuild the command/env, and rebind via `--session <id>`.

### Prune race

OpenCode may prune old sessions on startup. If `OPENCODE_DISABLE_PRUNE` isn't injected, a startup prune could delete the persisted `sessionID` before the provider rebinds to it. Recommend injecting `OPENCODE_DISABLE_PRUNE=true` per-pane (or gating restore on session existence via `GET /session/:id` before launching the TUI).

### Work to do

- Extend `Tab.refreshPane` and `restartPane` to handle `.opencode`:
  - Reallocate a fresh free port on every launch.
  - Rebuild `controller.pendingCommand` with the new `--port`.
  - Rebuild `OPENCODE_CONFIG_CONTENT` and other injected env vars.
  - Inject `--continue` or `--session <id>` on restart if `AppSettings.continueOnRestart` is true.
- Store enough state to rebind after restore: at minimum the pane id and, if continuing, the session id. The port is transient and reallocated on relaunch.
- Auto session names: because `POST /session {title?}` accepts a title at creation and the provider passes `--session <id>`, OpenCode panes **can** be auto-named in v1. The title format mirrors Claude's `<tab>/<pane>` convention.

## 10. Additional cross-cutting concerns

These are areas beyond the six categories in the original request that must be addressed before the feature is complete.

### No programmatic TUI driving

OpenCode exposes `POST /tui/submit-prompt`, `POST /tui/append-prompt`, `POST /tui/execute-command`, `POST /tui/show-toast`, `POST /tui/open-help`, `POST /tui/open-sessions`, `POST /tui/open-themes`, `POST /tui/open-models`. Agent Session Manager **must not** call any of these. The terminal pane is the user's surface — driving it programmatically would violate Terminal Purity (AGENTS.md) and undermine the worktree-per-pane model. The HTTP server is for status-line / notification observability only.

### Dev/prod build isolation

OpenCode's global config and plugin directories (`~/.config/opencode/`, `/Library/Application Support/opencode/`) are shared between Agent Session Manager's dev and production builds. Defenses:

- Env-var-only config injection (the §6 approach) avoids touching these directories.
- `OPENCODE_DISABLE_DEFAULT_PLUGINS=true` injected per-pane strips default plugins cleanly — use in dev builds for maximum isolation.
- For hooks, prefer the server API over global plugin installation. A one-time global plugin install is deprioritized because it affects the user's real OpenCode setup and violates dev/prod isolation.

### Issue tracking and invariants

Per AGENTS.md, every feature ties to a GitHub issue and contributes invariant-catalog entries. Before implementation:

- File a tracking issue for OpenCode support (referenced in commit messages and PR descriptions).
- Emit span attributes for harness detection, command build, status provider binding, server API calls, and failures.
- Keep output bounded (no prompts, no auth, no env secrets).

Add invariant-catalog entries per the `instrument-runtime-telemetry` skill:

- Worktree-name invariant (already enforced; OpenCode panes inherit the contract).
- Lines-added/removed invariant (if §7.3 switches to `/session/:id/diff`, the source changes but the invariant doesn't).
- OpenCode-specific invariants to add:
  - Per-pane port is localhost + ephemeral + mDNS-off.
  - `OPENCODE_CONFIG_CONTENT` is app-controlled per pane (not user-editable).
  - `sessionID` is bound and rebindable across restore.
  - No `/tui/*` endpoint called from the app (Terminal Purity extension).

### Terminal purity

`buildOpenCodeCommand()` must emit only the final `opencode ...` invocation. All setup — port allocation, config JSON construction, env var injection — happens in Swift using `Foundation.Process` or file APIs, never as prepended shell commands.

### No fake UI tests / screenshots

UI tests must create real OpenCode panes through the real New Pane sheet, run a real `opencode` process, and observe real status data. Do not add test-only branches to production code.

### Worktree and project root

OpenCode discovers project config by searching upward from the current directory to the nearest Git directory. Since Agent Session Manager runs OpenCode inside a git worktree under `.agent-session-manager/worktrees/<name>`, OpenCode should treat the worktree as the project root. Verify this behavior against the real binary, especially when the repo root also contains an `opencode.json`.

### Version/schema drift

Like Codex's `0.136.x` SQLite adapter (`CodexVersionAdapter` in `CodexStatusProvider.swift:66-81`), the OpenCode server API may change across versions. Implement `OpenCodeVersionAdapter` modeled on the Codex pattern: branch on `detectedHarnessVersion` (resolved via `GET /global/health`), gate field-population calls behind version predicates, and emit a bounded trace event when an endpoint or field is missing. Do **not** degrade silently — silent degradation masks breakage from the observability dashboard.

### Documentation artifacts to create during implementation

- `documentation/features/opencode-cli.md` — user-facing feature doc
- `.agents/skills/feature-opencode-cli/SKILL.md` — agent skill
- Update `AGENTS.md` "Feature Skills" section
- Update `documentation/features/agent-harness-feature-matrix.md`

## 11. Open questions

These need to be resolved before or during implementation.

1. **Random-port discovery.** [x] Closed: always pin `--port`.
2. **SSE vs polling.** [x] Closed: SSE works with `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true`; without it the stream is silent after `server.connected`. Fallback polling target is `GET /session/:id`; `/session/status` returns `{}` in 1.17.13.
3. **Background subagent idle behavior.** [x] Closed: subagents run as child sessions; the bound parent session's `session.idle` is accurate for its own lifecycle.
4. **Auto session names.** [x] Closed: `POST /session {title}` works against the embedded TUI server and `--session <id>` rebinds to it.
5. **Env-var catalog scope.** [x] Closed: expand to OpenCode in v1.
6. **`OPENCODE_CONFIG_CONTENT` limits.** [x] Closed: 16 KB and 512 KB pass; the only failure was shell `ARG_MAX` at ~1 MB, not OpenCode's loader.
7. **Cost data availability.** [x] Closed: `cost` and `tokens` are present on `GET /session/:id` and in SSE `session.updated` events.
8. **Rate limits.** [x] Closed: not documented.

## 12. Proposed implementation order

A phased approach keeps each stage compileable and testable.

0. **API spike** — `/doc` schema (resolve HTML vs JSON), SSE shapes (60s observation), cost/token field presence, background-subagent event semantics, `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM` gate, `OPENCODE_CONFIG_CONTENT` 8–16 KB stress test, `POST /session {title}` through embedded TUI server, `/global/health` for version.
1. **Enum + detection** — add `.opencode`, enable auto-activation when detected, update test assertions.
2. **CLI flag catalog + persistence + env-var catalog** — `opencodeAll`, `recommendedDefaults`, `AppSettings` fields, `SettingsPersistence` methods, build the harness-keyed env-var stack from scratch (no Codex/Cursor env-var pattern to mirror — see §4), expand `extraEnvVars` plumbing to all harness arms including `.shell` and `.opencode`.
3. **Command builder + launch** — `Tab.buildOpenCodeCommand`, free-port allocator, `addPane`/`completeSetup` wiring. Verify a pane can launch `opencode`.
4. **Config injection** — build and inject `OPENCODE_CONFIG_CONTENT`.
5. **Status provider** — `OpenCodeStatusProvider`, SSE/polling with 15s fallback cadence, model/token/context population, chip matrix finalized post-spike. Use `GET /global/health` for version (not `opencode --version`). Consider `GET /session/:id/diff` for `linesAdded`/`linesRemoved` (alternative to app-owned `git diff --stat`).
6. **Notifications** — attention/stopped events from server, sidebar integration, new `NotificationKind`/`Source` cases, toggle persistence, background-subagent gating if needed.
7. **Restore + continue** — persist session id, rebind on restore, re-allocate port and rebuild command/env on restart, `--continue`/`--session` on restart.
8. **Telemetry + invariants** — spans, invariant catalog, bounded output.
9. **Docs + skill** — feature doc (`documentation/features/opencode-cli.md`), skill (`.agents/skills/feature-opencode-cli/SKILL.md`), `AGENTS.md` "Feature Skills" entry, update `documentation/features/agent-harness-feature-matrix.md`.

---

*Last updated: July 6, 2026. Phase 0 spike complete; Phase 1 enum + detection complete; Phase 2 CLI flag catalog + persistence + env-var catalog + harness-aware decode complete; Phase 3 command builder + launch complete; Phase 4 `OPENCODE_CONFIG_CONTENT` injection complete; status provider deferred to Phase 5; restore/continue deferred to Phase 7.*

## Spike Findings

Spike run on **July 5, 2026** against `opencode` **v1.17.13** in the `.tree/opencode-support-2` worktree. Commands, logs, and captured JSON artifacts are under `/tmp/opencode-spike/`.

### 1. Schema discovery

- `GET /doc` returns an HTML Swagger UI by default. With `Accept: application/json` it returns a 478 KB OpenAPI 3.1 spec.
- Cross-reference: `packages/sdk/js/src/gen/types.gen.ts` from the `anomalyco/opencode` `dev` branch matches the live spec.

### 2. Health + version

- `GET /global/health` returns `{"healthy":true,"version":"1.17.13"}`.
- Use this for `detectedHarnessVersion` / `OpenCodeVersionAdapter`; do not parse `opencode --version`.

### 3. SSE event stream (`GET /event`)

- **Gating:** `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true` is **required**. Without it the stream emits only `server.connected` and then stays silent.
- **Observed events (with flag):** `server.connected`, `server.heartbeat` (~30 s), `session.created`, `session.updated`, `session.status`, `session.idle`, `session.diff`, `message.updated`, `message.part.updated`, `message.part.delta`, `permission.asked`, `permission.replied`.
- **Stability:** a 60 s curl-held connection stayed open, received heartbeats, and showed no silent disconnect or partial-event failures.

### 4. Session creation and binding

- `POST /session {"title":"spike/test"}` works against both `opencode serve` and the embedded TUI server (`opencode --port …`).
- Response includes `id`, `title`, `cost`, `tokens`, `version`, `model`, `agent`, `time`, `summary`.
- Passing `--session <id>` to `opencode` rebinds the TUI to that session.
- **Decision:** v1 will auto-name OpenCode panes by creating a session upfront and passing `--session <id>`.

### 5. Session / message fields

`GET /session/:id` returns:

- `model: {id, providerID, variant}` (not a string)
- `cost: number`
- `tokens: {input, output, reasoning, cache: {read, write}}` (no `total`, no `context`, no `contextRemaining`)
- `title: string`
- `agent: string`
- `version: string`
- `summary: {additions, deletions, files, diffs?}`

`GET /session/:id/message` returns assistant messages with the same `cost`/`tokens` plus `finish`.

**Chip impact:**

- `cost`, `inputTokens`, `outputTokens`, `model`, `sessionName`, `version` → **Yes**.
- `context` / `contextRemaining` → **No** (not exposed anywhere in 1.17.13).
- `rate5h` / `rate7d` → **No** (still undocumented).

### 6. Background subagent idle behavior

- With `OPENCODE_EXPERIMENTAL=true` and `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`, asking for a background task spawned a **child session** with `parentID` set to the original session.
- The parent session's `session.status` went `busy` → `idle` and emitted `session.idle` when its own turn finished, while the child session continued `busy` independently.
- **Decision:** no Claude-style `SubagentStop` gating is needed for v1; the bound session's `session.idle` accurately signals its own turn completion.

### 7. `OPENCODE_CONFIG_CONTENT` stress test

- Tested inline JSON sizes: 4 KB, 8 KB, 16 KB, 32 KB, 64 KB, 128 KB, 256 KB, **512 KB** — all loaded and `/config` reflected `share: "manual"`.
- **~1 MB failed**, but the failure was `zsh: argument list too long` from the shell invocation, not from OpenCode's loader.
- **Decision:** the 8–16 KB per-pane payload budget is safe. Swift `Process.environment` / `setenv` should avoid the shell `ARG_MAX` issue entirely.

### 8. Diff, VCS, and project root

- `GET /session/:id/diff` returned `[]` both before and after explicit filesystem edits via the `/session/:id/shell` endpoint. It does **not** reflect worktree changes; it appears to track session-internal snapshot diffs.
- **Decision:** keep `linesAdded`/`linesRemoved` as app-owned (`git diff --stat`) via `ToolAgnosticDataProvider`.
- `GET /vcs` returns `{"branch":"opencode-support-2","default_branch":"main"}` — useful for branch detection but app-owned git is still needed for line counts.
- `GET /path` returns `worktree` and `directory` paths.
- `GET /project/current` returns the main repo worktree with `sandboxes: [".../.tree/opencode-support-2"]`. OpenCode treats the main repo as the project root and the worktree as a sandbox.

### 9. Notifications / attention signals

- `permission.asked` event observed when asking OpenCode to read `/etc/hosts`:
  ```json
  {"type":"permission.asked","properties":{"id":"per_...","sessionID":"...","permission":"external_directory","patterns":["/etc/*"],"metadata":{...},"always":["/etc/*"],"tool":{"messageID":"...","callID":"read_0"}}}
  ```
- Map this to `PaneAttentionEvent.Source.opencodePermissionRequest`.
- Map `session.idle` to `PaneAttentionEvent.Source.opencodeStop` / `NotificationKind.opencodeStop`.

### 10. Open questions resolved

| # | Question | Resolution |
|---|---|---|
| 2 | SSE vs polling | SSE requires `OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true`; fallback is polling `GET /session/:id` because `/session/status` returns `{}`. |
| 3 | Background subagent idle behavior | Subagents run as child sessions; parent `session.idle` is accurate. |
| 4 | Auto session names | `POST /session {title}` works; pass `--session <id>`. |
| 6 | `OPENCODE_CONFIG_CONTENT` limits | 16 KB+ works; shell `ARG_MAX` is the only observed limit. |
| 7 | Cost data availability | `cost` and `tokens` are present on Session and in SSE events. |
