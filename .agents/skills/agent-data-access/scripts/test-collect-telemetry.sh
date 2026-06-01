#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
collector="$script_dir/collect-telemetry.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/agent-session-manager-telemetry-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

prod="$tmp/support dir/agent-session-manager"
dev="$tmp/support dir/agent-session-manager.dev"
mkdir -p "$prod/traces/tab one" "$prod/traces/_global" "$prod/invariants" "$dev"

cat > "$prod/debug-settings.json" <<'EOF'
{"schemaVersion":1,"enabled":true}
EOF
cat > "$prod/sessions.json" <<'EOF'
{"tabs":[{"id":"TAB-1111","name":"Tab One","directory":"/repo path","panes":[{"id":"PANE-AAAA-1111","name":"same pane","harness":"codex","worktreeDirectory":"/tree one"}]}]}
EOF
cat > "$prod/traces/tab one/closed.jsonl" <<'EOF'
{"_type":"metadata","paneId":"PANE-BBBB-2222","paneName":"same pane","tabId":"TAB-1111","tabName":"Tab One","createdAt":"2026-01-01T00:00:00Z"}
{"name":"closed.span","startEpochMs":2000,"endEpochMs":2001,"attributes":{"pane.id":"PANE-BBBB-2222"}}
malformed span
EOF
cat > "$prod/traces/tab one/current.jsonl" <<'EOF'
{"_type":"metadata","paneId":"PANE-AAAA-1111","paneName":"same pane","tabId":"TAB-1111","tabName":"Tab One","createdAt":"2026-01-01T00:00:00Z"}
{"name":"old.span","startEpochMs":999,"endEpochMs":1000,"attributes":{"pane.id":"PANE-AAAA-1111"}}
{"name":"current.one","startEpochMs":2000,"endEpochMs":2001,"attributes":{"pane.id":"PANE-AAAA-1111"}}
{"name":"current.two","startEpochMs":3000,"endEpochMs":3001,"attributes":{"pane.id":"PANE-AAAA-1111"}}
EOF
cat > "$prod/traces/_global/global.jsonl" <<'EOF'
{"_type":"metadata","paneId":"_global","paneName":"global","tabId":"_global","tabName":"_global","createdAt":"2026-01-01T00:00:00Z"}
{"name":"global.span","startEpochMs":2500,"endEpochMs":2501,"attributes":{}}
EOF
cat > "$prod/invariants/invariants.jsonl" <<'EOF'
{"_type":"metadata","schemaVersion":1}
{"id":"INV-1","invariantID":"test","timestamp":"1970-01-01T00:00:02Z","context":{"pane.id":"PANE-AAAA-1111"}}
bad invariant
EOF
printf 'legacy\n' > "$prod/debug-trace.log"
printf 'legacy\n' > "$prod/traces.jsonl"

run() {
  "$collector" --support-dir "$tmp/support dir" "$@"
}

if run --list >/dev/null 2>&1; then
  echo "expected --app to be required" >&2
  exit 1
fi

prod_json=$(run --app prod --tab "Tab One" --pane "same pane" --since 1000 --until 4000 --limit 1)
jq -e '
  .app == "prod" and
  .debugMode.enabled == true and
  (.currentSessionMatches | length) == 1 and
  (.candidateTraceFiles | length) == 2 and
  (.paneSpans | length) == 1 and .paneSpans[0].name == "current.two" and
  .truncation.paneSpans == true and
  (.matchingInvariantViolations | length) == 1 and
  (.correlatedGlobalSpans | length) == 1 and
  (.malformedLines | length) == 2 and
  ([.legacyFiles[] | select(.exists)] | length) == 2
' <<<"$prod_json" >/dev/null

narrow_json=$(run --app prod --pane-id pane-bbbb --since 1000 --until 4000)
jq -e '
  (.candidateTraceFiles | length) == 1 and
  .candidateTraceFiles[0].metadata.paneId == "PANE-BBBB-2222" and
  (.paneSpans | length) == 1 and .paneSpans[0].name == "closed.span"
' <<<"$narrow_json" >/dev/null

rfc3339_json=$(run --app prod --pane-id pane-aaaa --since 1970-01-01T00:00:01Z --until 1970-01-01T00:00:04Z)
jq -e '(.paneSpans | map(.name)) == ["current.one", "current.two"]' <<<"$rfc3339_json" >/dev/null

offset_json=$(run --app prod --pane-id pane-aaaa --since 1969-12-31T19:00:01-05:00 --until 1969-12-31T19:00:04-05:00)
jq -e '(.paneSpans | map(.name)) == ["current.one", "current.two"]' <<<"$offset_json" >/dev/null

list_json=$(run --app prod --list)
jq -e '(.candidateTraceFiles | length) == 2 and (.paneSpans | length) == 0' <<<"$list_json" >/dev/null

dev_json=$(run --app dev --list)
jq -e '
  .app == "dev" and .debugMode.exists == false and
  (.candidateTraceFiles | length) == 0 and
  ([.legacyFiles[] | select(.exists)] | length) == 0
' <<<"$dev_json" >/dev/null

echo "collect-telemetry fixture tests passed"
