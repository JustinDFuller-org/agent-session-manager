# Oh My Pi CLI Support

Agent Session Manager supports [Oh My Pi](https://omp.sh) as a fifth agent harness. Its persisted harness value and executable are `omp`; the product label is **Oh My Pi**.

## Launch and configuration

Agent Session Manager supports Oh My Pi versions `>= 17.2.11` and `< 18.0.0`. The selected interactive shell must report a compatible version before a pane is created. Select **Oh My Pi** in the New Pane sheet; incompatible, missing, or unrecognised installations remain in the sheet with an actionable error.

The final terminal command is terminal-pure: `omp … --extension <private-runtime>/main.mjs`. Each launch receives a new app-owned private runtime directory under the system temporary directory. The directory is mode `0700`; `main.mjs`, status snapshots, and optional `.mcp.json` are mode `0600`. Runtime directories are removed when their launch is replaced, converted to a shell, or closed.

CLI flags and environment variables are configurable in Settings and can be stored in profiles. The curated interactive surface excludes secrets and one-shot/noninteractive flags. Provider credentials remain environment-only. App-controlled variables cannot be overridden:

- `AGENT_SESSION_MANAGER_OMP_STATUS_FILE`
- `AGENT_SESSION_MANAGER_OMP_SESSION_NAME`

## Status and attention

The extension writes a bounded JSON snapshot through atomic replacement. `OhMyPiStatusProvider` merges it with the normal worktree, duration, diff, PR, and profile baseline. Oh My Pi supplies model, cumulative cost, input/output/cache token counts, context, effort/thinking level, and session name. Rate-limit, Vim, agent-name, output-style, and 200k-context facts remain unsupported because Oh My Pi does not expose authoritative data for them.

`agent_start` drives the working activity indicator. `agent_end` produces one completion attention event; tool-approval and input requests create permission and input attention entries. The **Notify when Oh My Pi stops** setting controls completion notifications. A terminal input clears the pane's outstanding attention entry.

## Sessions and restart

When the extension reports a persistent session ID, the app saves it with the pane. With **Continue on app restart** enabled, a restored or quick-refreshed pane uses `--resume <saved-id>`; without a saved ID it uses `--continue`. Explicit `--resume`, `-r`, `--continue`, `-c`, `--from-claude`, `--from-codex`, or `--no-session` options always win. A reported session ID that differs from the expected resumed session fails closed: the pane stops, removes its runtime, and presents a retryable error.

## Agent Control

With Agent Control enabled, the app writes a private root `.mcp.json` using OMP's `mcpServers` schema and adds `--plugin-dir <private-runtime>`. The status extension remains independently explicit as `--extension <private-runtime>/main.mjs`; it loads exactly once. The configuration contains only the loopback server URL and an environment-variable bearer-token placeholder. Setup failure is fail-closed for Oh My Pi panes. `--no-extensions` suppresses ambient discovery but does not remove this explicit private extension.

## Diagnostics

The integration emits bounded pane-scoped traces for package setup, snapshots, attention, session binding, and Agent Control preparation. It never records a full session ID, status payload, token, environment value, path, or tool reason. Invariants:

- `omp.runtime_plugin.private` — package ownership and private permissions.
- `omp.session.rebindable` — a restored pane must bind to its expected session ID.

See [the harness matrix](agent-harness-feature-matrix.md) for cross-harness support.