# Oh My Pi CLI Support

Agent Session Manager supports [Oh My Pi](https://omp.sh) as a fifth agent harness. Its persisted harness value and executable are `omp`; the product label is **Oh My Pi**.

## Launch and configuration

Select **Oh My Pi** in the New Pane sheet. The normal worktree flow resolves the checkout, then the app launches the terminal-pure final command `omp … --extension <private-package>`. The private extension package is created in the system temporary directory, never in the checkout.

Oh My Pi is available when `omp --version` succeeds in the selected interactive shell. CLI flags and environment variables are configurable in Settings and can be stored in profiles. App-controlled variables cannot be overridden:

- `AGENT_SESSION_MANAGER_OMP_STATUS_FILE`
- `AGENT_SESSION_MANAGER_OMP_SESSION_NAME`

The extension package is app-owned, mode `0700`; its package, source, status snapshot, and optional MCP configuration are mode `0600`. It is removed when the pane becomes a shell, changes harness, or closes.

## Status and attention

The extension writes a bounded JSON snapshot through atomic replacement. `OhMyPiStatusProvider` merges it with the normal worktree, duration, diff, PR, and profile baseline. Oh My Pi supplies model, cumulative cost, input/output/cache token counts, context, effort/thinking level, and session name. Rate-limit, Vim, agent-name, output-style, and 200k-context facts remain unsupported because Oh My Pi does not expose authoritative data for them.

`agent_start` drives the working activity indicator. `agent_end` produces one completion attention event; tool-approval and input requests create permission and input attention entries. The **Notify when Oh My Pi stops** setting controls completion notifications. A terminal input clears the pane's outstanding attention entry.

## Sessions and restart

When the extension reports a persistent session ID, the app saves it with the pane. With **Continue on app restart** enabled, a restored pane uses `--resume <saved-id>`; without a saved ID it uses `--continue`. An explicit `--resume`, `-r`, `--continue`, `-c`, or `--no-session` option always wins. Automatic session naming sets the session to `<tab>/<pane>` after first input when enabled.

## Agent Control

With Agent Control enabled, the app writes a private sibling `mcp.json` inside the runtime package. It contains only the loopback server URL and a literal environment-variable bearer-token placeholder; tokens and checkout configuration are never written there. Setup failure is fail-closed for Oh My Pi panes. `--no-extensions` suppresses ambient extensions but does not remove this explicit private extension.

## Diagnostics

The integration emits bounded pane-scoped traces for package setup, snapshots, attention, session binding, and Agent Control preparation. It never records a full session ID, status payload, token, environment value, path, or tool reason. Invariants:

- `omp.runtime_plugin.private` — package ownership and private permissions.
- `omp.session.rebindable` — a restored pane must bind to its expected session ID.

See [the harness matrix](agent-harness-feature-matrix.md) for cross-harness support.