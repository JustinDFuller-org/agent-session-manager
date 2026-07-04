# OpenCode Harness Support Plan

This document is a working plan for adding [OpenCode](https://opencode.ai) as a fourth agent harness in Agent Session Manager, alongside Claude Code, Codex, and Cursor. It captures what has been researched so far, the architectural decisions already made, the remaining open questions, and a proposed implementation order. It is intentionally not polished end-user documentation; the user-facing feature doc will be created later at `documentation/features/opencode-cli.md`.

## Progress

Legend: `[ ]` not started, `[~]` in progress, `[x]` complete.

### Implementation phases

| # | Phase | Status | Notes |
|---|---|---|---|
| 1 | [Enum + detection](#1-harness-enum-and-detection) | [ ] | |
| 2 | [CLI flag catalog + persistence](#3-cli-flags) | [ ] | |
| 3 | [Command builder + launch](#3-cli-flags) | [ ] | |
| 4 | [Config injection (`OPENCODE_CONFIG_CONTENT`)](#6-modifying-opencode-inputs-to-work-well-with-agent-session-manager) | [ ] | |
| 5 | [Status provider](#7-status-line-support) | [ ] | |
| 6 | [Notifications](#8-notifications-and-attention) | [ ] | |
| 7 | [Restore + continue](#9-session-persistence-restore-and-continue-on-restart) | [ ] | |
| 8 | [Telemetry + invariants](#10-additional-cross-cutting-concerns) | [ ] | |
| 9 | [Docs + skill](#10-additional-cross-cutting-concerns) | [ ] | |

### Open questions

| # | Question | Status | Resolution |
|---|---|---|---|
| 1 | Random-port discovery | [ ] | |
| 2 | SSE vs polling | [ ] | |
| 3 | Background subagent idle behavior | [ ] | |
| 4 | Auto session names | [ ] | |
| 5 | Env-var catalog scope | [ ] | |
| 6 | `OPENCODE_CONFIG_CONTENT` limits | [ ] | |
| 7 | Cost data availability | [ ] | |
| 8 | Rate limits | [ ] | |

## Decisions already made

| Area | Decision | Rationale |
|---|---|---|
| Activation | Enabled by default if detected during onboarding | OpenCode should be immediately available when it is on the user's PATH, instead of requiring a manual opt-in toggle like Codex/Cursor. |
| Config injection for ASM-owned overrides | `OPENCODE_CONFIG_CONTENT` env var | Highest-precedence non-managed config source, terminal-pure (no shell prepending), and scoped per-pane without touching the user's worktree. |
| Status line strategy | HTTP server API | OpenCode already runs a per-TUI HTTP server with a documented REST/SSE surface. This is more robust than scraping files or installing a global plugin. |

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
- The hook analog is JS/TS plugins placed in `.opencode/plugins/` or `~/.config/opencode/plugins/`, or listed in the `plugin` config key. Relevant plugin events include `session.created`, `session.updated`, `session.idle`, `permission.asked`, `message.updated`, `tool.execute.before/after`, `shell.env`.

Sources: [OpenCode Config docs](https://opencode.ai/docs/config/), [CLI docs](https://opencode.ai/docs/cli/), [Server docs](https://opencode.ai/docs/server/), [Plugins docs](https://opencode.ai/docs/plugins/).

## 1. Harness enum and detection

### Work to do

- Add `case opencode` to `Harness` in `Sources/AgentSessionManager/Models/Pane.swift`.
  - `displayName`: "OpenCode"
  - `commandDescription`: "opencode" (the binary name)
- Add `.opencode` to `Harness.allCases` so it appears everywhere the UI iterates user-facing harnesses.
- `HarnessDetector.detectInstalled(shell:)` already probes `tool.commandDescription` with `which <cmd>`, so OpenCode detection is automatic once the enum case exists.
- Onboarding `OnboardingWizardView.toolsStep` iterates `Harness.allCases`, so OpenCode will appear in the detection list without extra view work.
- Update `StatusLineConfig.allHarnesses` and any capability sets that currently read `[.claude, .codex, .cursor]`.

### Decision note

OpenCode is enabled by default when detected. This means `appSettings.activeTools` should include `"opencode"` after onboarding if `HarnessDetector` finds it. The onboarding "Continue" button already loops `checkedTools` and calls `setActive(_:true)`, so the only change is defaulting the toggle to on when detected.

## 2. Onboarding

### Work to do

- Ensure the OpenCode toggle in the tools step is checked by default when detected.
- In `OnboardingWizardView.cliFlagsStep`, seed `draftCliOptions[.opencode]` with `CLIOptionConfig.recommendedDefaults(for: .opencode)` when OpenCode is in `checkedTools`.
- Decide whether the env-var editor should show OpenCode env vars or remain Claude-only. See §5.
- Save OpenCode CLI options during onboarding using a new `SettingsPersistence.saveOpenCodeOptions(appSettings:)` call.

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
- Add `Tab.buildOpenCodeCommand(port:extraArgs:)` that emits only the final invocation, e.g. `opencode --port 12345 --continue`.
- Wire `.opencode` into `Tab.addPane`/`completeSetup`/`refreshPane`/`restartPane`.
- Respect Terminal Purity: no setup commands in the terminal string; `--port` and other injected flags are computed in Swift and appended to the final command.

### Important note on `--port`

The status-line provider needs to know which server belongs to the pane. The reliable approach is to allocate a free port in Swift (bind-and-release a socket) and pass it via `--port`. Each OpenCode pane therefore runs on its own predictable port, which also matches the per-pane isolation model. A random-port default would require discovering the port from OpenCode stdout or a known file; that should be documented as a fallback only.

## 4. CLI environment variables

OpenCode exposes many `OPENCODE_*` env vars. Relevant categories for the settings sheet:

- Config path: `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `OPENCODE_TUI_CONFIG`, `OPENCODE_CONFIG_CONTENT`
- Server auth: `OPENCODE_SERVER_PASSWORD`, `OPENCODE_SERVER_USERNAME`
- Behavior: `OPENCODE_AUTO_SHARE`, `OPENCODE_DISABLE_AUTOUPDATE`, `OPENCODE_DISABLE_TERMINAL_TITLE`, `OPENCODE_DISABLE_AUTOCOMPACT`, `OPENCODE_DISABLE_MOUSE`, `OPENCODE_PERMISSION`
- Claude-code interop: `OPENCODE_DISABLE_CLAUDE_CODE`, `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT`, `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS`
- Experimental: `OPENCODE_EXPERIMENTAL_*`, `OPENCODE_ENABLE_EXPERIMENTAL_MODELS`, etc.

### Work to do

- Decide whether to create an `EnvVarConfig.opencodeAll` catalog and allow per-profile env vars for OpenCode, or keep the env-var editor Claude-only (like Codex/Cursor today).
- If per-harness env vars are supported, add a second env-var picker in `OnboardingWizardView.cliFlagsStep` keyed by the selected harness, and add `ProfileEnvVar` support.
- Reserve `OPENCODE_CONFIG_CONTENT` for internal use in §6; it should not be editable in the user-facing env-var sheet, because Agent Session Manager will write it itself.

## 5. Profile creation

### Work to do

- `Profile.harness` is already a `Harness`, so `.opencode` profiles require no model changes.
- `ProfileCLIOption` IDs will be drawn from `CLIOptionConfig.opencodeAll`.
- `ProfileEnvVar` support depends on the §4 decision.
- Ensure `ProfileSettingsViews` and `StatusLineConfig` pickers treat `.opencode` as a first-class harness.
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

- It cannot install a plugin or hook script. Plugins require a file on disk in `.opencode/plugins/` or `~/.config/opencode/plugins/`.
- It cannot reference per-pane temp files inside JSON (unless we use env-var substitution, which OpenCode supports via `{env:VAR}`).

Therefore status-line/attention hooks should use the HTTP server API (§7) rather than a plugin. If the server API proves insufficient for attention notifications, a one-time global plugin install is the fallback.

### Work to do

- Create a helper that builds the per-pane inline JSON config.
- Inject it into `controller.pendingEnvironment` as `OPENCODE_CONFIG_CONTENT=<json>`.
- Ensure user-provided `OPENCODE_CONFIG_CONTENT` values are respected or merged; document the conflict behavior.

## 7. Status line support

This is the largest integration surface. The plan is to connect to each pane's OpenCode server and read live session data.

### 7.1 Per-pane port allocation

Each `opencode` TUI starts its own server. Agent Session Manager must ensure each pane's server is reachable.

- Allocate a free port in Swift before launching the pane (bind a temporary socket, read the port, close it, pass `--port <port>` to OpenCode).
- Store the allocated port with the pane controller so the status provider can connect.
- On restore, reallocate a port and relaunch OpenCode on that port; OpenCode session state is preserved via `--session <id>` or `--continue`.
- Collision risk exists across dev/prod builds because ports are OS-wide; the allocator mitigates this but a race window remains between allocation and bind. Document and accept, or implement a retry loop.

### 7.2 Session binding

A single pane/server may host multiple sessions over time. The provider needs to know which session is "the pane's session."

- When the user continues a session, pass `--session <id>`. The provider then binds to that exact id.
- For a fresh pane, call `GET /session/status` on the pane's port and select the active/running session (or the most recently updated session if none is marked active).
- Store the bound `sessionID` on the pane so restore/restart rebinds to the same session.

### 7.3 `OpenCodeStatusProvider`

Create a new provider conforming to `StatusLineDataProvider`, modeled on `CodexStatusProvider`.

- Use `ToolAgnosticDataProvider` as the baseline for worktree, branch, duration, changed lines, version, and PR data.
- Start a polling task (or SSE connection to `GET /event`) against `http://localhost:<port>`.
- Parse responses from `/session/status` and `/session/:id` to populate:
  - `model`
  - `inputTokens`, `outputTokens`, `context`, `contextRemaining`
  - `cost` (if exposed)
  - `version`
  - `sessionName` (if exposed)
- Merge baseline and harness data in `emitMerged()`, following the `CodexStatusProvider` pattern.
- Add bounded tracing for binding attempts, parse failures, and field presence. Do not log prompts, messages, or auth data.

### 7.4 `StatusLineMonitor` wiring

- In `StatusLineMonitor.init`, add an `.opencode` branch that creates `OpenCodeStatusProvider`.
- Inject environment variables into the pane:
  - `AGENT_SESSION_MANAGER_PANE_ID=<pane-id>` (consistent with Cursor/Codex)
  - `AGENT_SESSION_MANAGER_OPENCODE_PORT=<port>` (optional, for diagnostics/plugins)
  - `OPENCODE_CONFIG_CONTENT=<json>`
- Update `StatusLineConfig.itemCapabilities` so OpenCode-capable chips are selectable.

### 7.5 Chip capability classification

Proposed OpenCode support per chip:

| Chip | Source | Initial target |
|---|---|---|
| `model` | Server API | Yes |
| `inputTokens` | Server API | Yes |
| `outputTokens` | Server API | Yes |
| `context` / `contextRemaining` | Server API | Yes |
| `cost` | Server API / `opencode stats` | Yes, if exposed |
| `version` | `opencode --version` | Yes |
| `sessionName` | Server API | Yes, if exposed |
| `duration` | App-owned | Yes |
| `worktree` | App-owned | Yes |
| `linesAdded` / `linesRemoved` | App-owned | Yes |
| `pr` | App-level PR tracking | Yes |
| `profileName` | App state | Yes |
| `rate5h` / `rate7d` | Likely N/A | No |
| `effort` / `thinking` / `vimMode` / `agentName` / `outputStyle` / `exceeds200k` | Claude-specific | No |

## 8. Notifications and attention

OpenCode does not use the same hook file mechanism as Claude Code, but it exposes equivalent signals.

- `permission.asked` plugin event or server event corresponds to "needs user attention."
- `session.idle` corresponds to "the agent finished a turn."

### Work to do

- Consume attention/stopped signals from the server SSE stream (`GET /event`) inside `OpenCodeStatusProvider`.
- Map `session.idle` to `PaneNotification` / sidebar entries, similar to Claude's `Stop` hook.
- Map permission events to attention notifications.
- Investigate whether `session.idle` fires prematurely while background subagents are running (OpenCode has `experimental.background_subagents`). If so, implement suppression logic analogous to Claude's `SubagentStop` / `PreToolUse` gating.
- Add any new `NotificationKind` cases needed for OpenCode.

## 9. Session persistence, restore, and continue-on-restart

### Work to do

- `PersistedPane.harness` is a `Harness` enum. Adding `.opencode` is backward compatible because the existing decoder falls back to `.claude` for unknown values.
- Extend `Tab.refreshPane` and `restartPane` to handle `.opencode`:
  - Preserve or recompute the allocated port.
  - Inject `--continue` or `--session <id>` on restart if `AppSettings.continueOnRestart` is true.
- Store enough state to rebind after restore: at minimum the pane id and, if continuing, the session id. The port is transient and reallocated on relaunch.
- Auto session names: today this is Claude-only (`--name '<tab>/<pane>'`). OpenCode TUI `--session` takes an ID, not a display name; `opencode run` supports `--title`. Decide whether to implement auto-naming for OpenCode or leave it Claude-only. If implemented, it may require using the server API to rename the session after creation.

## 10. Additional cross-cutting concerns

These are areas beyond the six categories in the original request that must be addressed before the feature is complete.

### Dev/prod build isolation

OpenCode's global config and plugin directories (`~/.config/opencode/`, `/Library/Application Support/opencode/`) are shared between Agent Session Manager's dev and production builds. If we ever install a global plugin or managed config, a dev run would affect the user's real OpenCode setup. The recommended env-var-only approach avoids this risk for config. For hooks, prefer the server API over global plugin installation.

### Telemetry and invariants

Per the `instrument-runtime-telemetry` skill, every runtime behavior change must:

- Emit span attributes for harness detection, command build, status provider binding, server API calls, and failures.
- Add invariant catalog entries if any invariants are enforced (e.g. worktree name, lines added/removed).
- Keep output bounded (no prompts, no auth, no env secrets).

### Terminal purity

`buildOpenCodeCommand()` must emit only the final `opencode ...` invocation. All setup — port allocation, config JSON construction, env var injection — happens in Swift using `Foundation.Process` or file APIs, never as prepended shell commands.

### No fake UI tests / screenshots

UI tests must create real OpenCode panes through the real New Pane sheet, run a real `opencode` process, and observe real status data. Do not add test-only branches to production code.

### Worktree and project root

OpenCode discovers project config by searching upward from the current directory to the nearest Git directory. Since Agent Session Manager runs OpenCode inside a git worktree under `.agent-session-manager/worktrees/<name>`, OpenCode should treat the worktree as the project root. Verify this behavior against the real binary, especially when the repo root also contains an `opencode.json`.

### Version/schema drift

Like Codex's `0.136.x` SQLite adapter, the OpenCode server API may change across versions. Implement version detection (`opencode --version`) and degrade gracefully to baseline facts if an endpoint or field is missing.

### Documentation artifacts to create during implementation

- `documentation/features/opencode-cli.md` — user-facing feature doc
- `.agents/skills/feature-opencode-cli/SKILL.md` — agent skill
- Update `AGENTS.md` "Feature Skills" section
- Update `documentation/features/agent-harness-feature-matrix.md`

## 11. Open questions

These need to be resolved before or during implementation.

1. **Random-port discovery.** If we ever decide not to pin `--port`, how does Agent Session Manager discover the server's URL? Does OpenCode print it to stdout, write a pidfile, or expose a well-known endpoint?
2. **SSE vs polling.** Should `OpenCodeStatusProvider` use `GET /event` (server-sent events) or periodic polling of `/session/status`? SSE is more efficient but may complicate lifecycle/cancellation in Swift concurrency.
3. **Background subagent idle behavior.** Does `session.idle` fire while `experimental.background_subagents` tasks are still running? If so, what event signals their completion?
4. **Auto session names.** Can OpenCode TUI sessions be named at launch, or only via `opencode run --title` / server API after creation?
5. **Env-var catalog scope.** Should OpenCode get its own env-var catalog in Settings, or should env vars remain Claude-only?
6. **`OPENCODE_CONFIG_CONTENT` limits.** Is there a practical size limit for inline JSON passed as an env var? Does it support all config keys, including nested objects?
7. **Cost data availability.** Does the server API expose cumulative cost, or is `opencode stats` the only source?
8. **Rate limits.** Does OpenCode expose Anthropic-style rate-limit windows, or are those provider-internal?

## 12. Proposed implementation order

A phased approach keeps each stage compileable and testable.

1. **Enum + detection** — add `.opencode`, enable auto-activation when detected.
2. **CLI flag catalog + persistence** — `opencodeAll`, `recommendedDefaults`, `AppSettings` field, `SettingsPersistence` methods.
3. **Command builder + launch** — `Tab.buildOpenCodeCommand`, port allocation, `addPane`/`completeSetup` wiring. Verify a pane can launch `opencode`.
4. **Config injection** — build and inject `OPENCODE_CONFIG_CONTENT`.
5. **Status provider** — `OpenCodeStatusProvider`, server polling/SSE, model/token/context/cost population.
6. **Notifications** — attention/stopped events from server, sidebar integration, background-subagent gating if needed.
7. **Restore + continue** — persist session id, rebind on restore, `--continue`/`--session` on restart.
8. **Telemetry + invariants** — spans, invariant catalog, bounded output.
9. **Docs + skill** — feature doc, skill, matrix update.

---

*Last updated: July 4, 2026. This plan will be refined as open questions are answered and implementation begins.*
