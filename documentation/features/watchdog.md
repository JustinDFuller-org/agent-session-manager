# External Watchdog

The app cannot report its own `SIGKILL` or a signal it never handles — see
`documentation/features/tracing.md` for why `app-lifecycle.json` and trace spans stop the moment
the process dies. The watchdog is a separate process, installed as a per-user `LaunchAgent`, that
samples the app's presence from outside it and keeps its own log that the app can neither write to
nor delete.

## What it samples

Every 60 seconds `scripts/watchdog-sample.sh`:

1. Looks up the running `AgentSessionManager` process via `pgrep -x`.
2. Appends one line to `~/Library/Logs/AgentSessionManagerWatchdog/watchdog.jsonl`:
   `{"ts", "present", "pid", "rss_kb"}`.
3. On a presence transition (the app was running last tick and is not now, or vice versa), appends
   richer context to `~/Library/Logs/AgentSessionManagerWatchdog/watchdog-transitions.log`: the
   last sample, `vm_stat`, `uptime`, and a best-effort listing of
   `/Library/Logs/DiagnosticReports` (reading that directory's contents needs elevation the
   watchdog does not have; the listing still surfaces filenames and timestamps when permitted).

Both log files live under `~/Library/Logs/`, outside every directory the app itself reads, writes,
or cleans up.

## Install

```sh
make install-watchdog
```

This renders `scripts/com.justinfuller.agent-session-manager.watchdog.plist.template` with the
repository's absolute script path and log directory, writes it to
`~/Library/LaunchAgents/com.justinfuller.agent-session-manager.watchdog.plist`, and loads it via
`launchctl`. Re-running the target is safe; it unloads any existing copy first.

```sh
make uninstall-watchdog
```

Unloads the agent and removes the plist. Existing log files are left in place.

## Verifying it caught something

```sh
tail -f ~/Library/Logs/AgentSessionManagerWatchdog/watchdog.jsonl
kill -9 "$(pgrep -x AgentSessionManager)"
# within 60s, watchdog-transitions.log gains a `true -> false` entry with the last sample and
# system context; the next `AgentSessionManager` launch separately reports `previous_exit=unclean`
# via ApplicationLifecycleMarker.
```
