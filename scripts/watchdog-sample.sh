#!/bin/bash
# One watchdog tick: sample AgentSessionManager's presence and footprint, append to a
# durable JSONL log outside the app's own Application Support directory, and on a
# presence transition capture the richer context (vm_stat, load, DiagnosticReports
# listing) needed to diagnose a death the app itself never got to record.
set -uo pipefail

APP_NAME="${AGENT_SESSION_MANAGER_WATCHDOG_APP_NAME:-AgentSessionManager}"
LOG_DIR="$HOME/Library/Logs/AgentSessionManagerWatchdog"
SAMPLE_LOG="$LOG_DIR/watchdog.jsonl"
TRANSITION_LOG="$LOG_DIR/watchdog-transitions.log"

mkdir -p "$LOG_DIR"

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

pid=$(pgrep -x "$APP_NAME" | head -1)
if [[ -n "$pid" ]]; then
    present="true"
    rss_kb=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
else
    present="false"
    rss_kb=""
fi

previous_present=""
if [[ -f "$SAMPLE_LOG" ]]; then
    previous_present=$(tail -1 "$SAMPLE_LOG" | sed -n 's/.*"present":\([a-z]*\).*/\1/p')
fi

sample=$(printf '{"ts":"%s","present":%s,"pid":"%s","rss_kb":"%s"}' \
    "$(timestamp)" "$present" "${pid:-}" "${rss_kb:-}")
echo "$sample" >> "$SAMPLE_LOG"

if [[ -n "$previous_present" && "$previous_present" != "$present" ]]; then
    {
        echo "=== presence transition: $previous_present -> $present at $(timestamp) ==="
        echo "last sample: $sample"
        echo "--- vm_stat ---"
        vm_stat
        echo "--- uptime / load ---"
        uptime
        echo "--- /Library/Logs/DiagnosticReports (best effort, may need elevation) ---"
        ls -lt /Library/Logs/DiagnosticReports 2>&1 | head -10
        echo
    } >> "$TRANSITION_LOG"
fi
