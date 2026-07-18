# OpenCode CLI Support

Agent Session Manager supports [OpenCode](https://opencode.ai) alongside Claude Code, Codex, and Cursor.

## What It Does

When you create a pane with OpenCode selected, the app resolves or creates a worktree through the shared New Pane flow and launches `opencode` in that checkout. The app allocates an ephemeral localhost port for the per-pane HTTP server, injects the app-owned `OPENCODE_CONFIG_CONTENT` config, and binds the status-line provider to that server.

## How to Enable

OpenCode is **enabled by default when detected** during onboarding. If `opencode` is on your interactive shell's PATH, it appears in the CLI picker and no manual toggle is required.

If you later disable it, re-enable it the same way as Codex or Cursor:

1. Open **Settings** (⌘,)
2. Go to the **Tools** tab
3. Toggle **OpenCode** on

Once enabled, "OpenCode" appears as an option in the CLI picker when creating a new pane.

## Creating an OpenCode Pane

1. Open a tab pointing to your project directory
2. Press **⌘⇧N** (or click **+** in the pane area) to open the New Pane sheet
3. Select **OpenCode** in the CLI segmented picker
4. Enter a session name
5. Click **Open**

The pane launches `opencode --hostname 127.0.0.1 --mdns=false --port <port>` in the resolved checkout. The port is chosen per pane by the app and is not persisted.

## Configuring CLI Flags

OpenCode-specific flags can be enabled or disabled in **Settings → CLI Tools → OpenCode**. The default selection is `--model` only; additional flags can be turned on to make them appear as toggles or text fields in the New Pane sheet.

### Available Flags

| Flag | Type | Description |
|------|------|-------------|
| `--agent` | string | Agent to use for the OpenCode session |
| `--auto` | boolean | Auto-approve permissions not explicitly denied |
| `--continue` | boolean | Continue the last OpenCode session |
| `--cors` | string | Additional browser origin(s) allowed for CORS |
| `--fork` | boolean | Fork the session when continuing |
| `--hostname` | string | Hostname for the per-pane local HTTP server (default: 127.0.0.1) |
| `--mdns` | boolean | Enable mDNS discovery for the local server |
| `--mdns-domain` | string | Custom mDNS domain name |
| `--model` | string | Model to use for the OpenCode session (`provider/model`) |
| `--port` | string/number | Port for the per-pane local HTTP server |
| `--prompt` | string | Initial prompt to use when starting the session |
| `--session` | string | Session ID to continue |

Agent Session Manager always pins `--hostname 127.0.0.1` and `--mdns=false` for security. Changing `--hostname` or `--mdns` from the UI can violate the per-pane localhost policy and will trigger an invariant warning.

## Configuring Environment Variables

OpenCode-specific environment variables can be enabled or disabled in **Settings → Environment Variables → OpenCode**. The default selection includes `OPENCODE_AUTO_SHARE`, `OPENCODE_DISABLE_AUTOUPDATE`, `OPENCODE_CLIENT`, and `OPENCODE_DISABLE_DEFAULT_PLUGINS`.

### App-Controlled Variables

The following variables are reserved for Agent Session Manager and do not appear in the user-facing editor:

- `OPENCODE_CONFIG_CONTENT` — written per pane with the app-owned config (`{"share":"manual","autoupdate":false}`)
- `OPENCODE_PERMISSION` — overridden by the injected `OPENCODE_CONFIG_CONTENT`

Setting these manually in a custom env var would be silently ignored.

## Status Line

OpenCode uses app-owned baseline status plus a per-pane HTTP provider. The provider connects to `http://127.0.0.1:<port>` and reads from the OpenCode server. It requires the experimental event system (`OPENCODE_EXPERIMENTAL_EVENT_SYSTEM=true`), with a 15-second polling fallback to `GET /session/:id` if the server-sent event stream cannot be sustained.

The provider populates the following chips:

| Chip | Source |
|------|--------|
| `model` | `GET /session/:id` / SSE `session.updated` |
| `inputTokens` | `GET /session/:id` / SSE `session.updated` |
| `outputTokens` | `GET /session/:id` / SSE `session.updated` |
| `cost` | `GET /session/:id` / SSE `session.updated` |
| `version` | `GET /global/health` |
| `sessionName` | `GET /session/:id` (set via `POST /session {title}` at creation) |
| `worktree` | App-owned checkout directory plus Git branch |
| `linesAdded` / `linesRemoved` | App-owned `git diff --shortstat HEAD` |
| `duration` | App-owned process duration |
| `pr` | App-level GitHub CLI polling |
| `profileName` | App state |

OpenCode does not expose context window or rate-limit data in the tested API, so `context`, `contextRemaining`, `rate5h`, `rate7d`, `rate5hReset`, `rate7dReset`, and Claude-specific chips (`effort`, `thinking`, `vimMode`, `agentName`, `outputStyle`, `exceeds200k`) are not populated for OpenCode panes.

## Notifications and Attention

OpenCode attention events are driven by the server's SSE stream:

- `session.idle` → `opencodeStop` notification and sidebar entry
- `permission.asked` → `opencodePermissionRequest` sidebar entry

Background subagents run as child sessions with their own session ID; the parent session's `session.idle` is accurate for the parent pane, so no extra gating is needed.

## Session Persistence and Continue on Restart

OpenCode pane names, options, resolved checkout paths, and the bound session ID are saved in `sessions.json`. On relaunch, the pane is restored when its checkout still exists.

When `Continue on app restart` is enabled, the restore path relaunches `opencode` with `--session <session-id>` and injects `OPENCODE_DISABLE_PRUNE=true` so the persisted session is not pruned before the TUI reconnects. If the session ID is unavailable, the pane falls back to `--continue`. The server port is always reallocated on every launch.

## Invariants

OpenCode contributes the following runtime invariants to the observability dashboard:

- `opencode.port.policy` — every pane must bind localhost, ephemeral port, and mDNS off
- `opencode.session.rebindable` — a session ID must be bound and rebindable across restore
- `opencode.tui.endpoints_unused` — the app must not call forbidden `/tui/*` endpoints
- `opencode.config_content.app_controlled` — `OPENCODE_CONFIG_CONTENT`/`OPENCODE_PERMISSION` must not be overridden by user env vars

See [agent-harness-feature-matrix.md](agent-harness-feature-matrix.md) for the cross-harness audit.
