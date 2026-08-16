#!/usr/bin/env bash
# Serialized, agent-owned Dev validation. This script deliberately never touches
# production or ordinary Dev persistence, and never uses broad process matching.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/recursive-development.sh start [--run-id UUID]
       scripts/recursive-development.sh status --run-id UUID
       scripts/recursive-development.sh collect --run-id UUID [--tab NAME --pane NAME]
       scripts/recursive-development.sh profile --run-id UUID [--seconds N]
       scripts/recursive-development.sh stop --run-id UUID
EOF
  exit 2
}
die() { printf 'recursive-development: %s\n' "$*" >&2; exit 1; }

root=$(git rev-parse --show-toplevel)
common=$(git rev-parse --path-format=absolute --git-common-dir)
common_root=$(dirname "$common")
cd "$root"
command=${1:-}; [[ -n $command ]] || usage; shift || true
run_id= tab= pane= seconds=15
while (($#)); do
  case "$1" in
    --run-id) (($# >= 2)) || usage; run_id=$2; shift 2 ;;
    --tab) (($# >= 2)) || usage; tab=$2; shift 2 ;;
    --pane) (($# >= 2)) || usage; pane=$2; shift 2 ;;
    --seconds) (($# >= 2)) || usage; seconds=$2; shift 2 ;;
    *) usage ;;
  esac
done
if [[ -n $run_id ]] && ! [[ $run_id =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
  die 'run ID must be a canonical UUID'
fi
if [[ -n $run_id ]]; then run_id=$(tr '[:upper:]' '[:lower:]' <<<"$run_id"); fi
support_base="$HOME/Library/Application Support/agent-session-manager-recursive-runs"
artifact_base="$root/.build/recursive-development"
bundle="$common_root/AgentSessionManagerDev.app"
lock="$common/recursive-development.lock"
manifest() { printf '%s/%s/agent-session-manager.dev/recursive-development-runtime.json' "$support_base" "$run_id"; }
artifacts() { printf '%s/%s' "$artifact_base" "$run_id"; }

require_run() { [[ -n $run_id ]] || die '--run-id is required'; }
require_jq() { command -v jq >/dev/null || die 'jq is required for recursive-development artifacts'; }
pid_is_live() { [[ $1 =~ ^[0-9]+$ ]] && kill -0 "$1" 2>/dev/null; }
read_pid() { jq -r '.pid // empty' "$(manifest)" 2>/dev/null; }
verify_owned_manifest() {
  local file pid expected_title commit bundle_path
  file=$(manifest); [[ -f $file ]] || die 'owned runtime manifest is missing'
  pid=$(read_pid); expected_title="Agent Session Manager (Dev · ${run_id:0:8})"
  commit=$(git rev-parse HEAD); bundle_path=$(cd "$bundle" && pwd)
  [[ $(jq -r '.runID' "$file") == "$run_id" ]] || die 'manifest run ID mismatch'
  [[ $(jq -r '.bundleURL' "$file") == "$bundle_path" ]] || die 'manifest bundle mismatch'
  [[ $(jq -r '.commit' "$file") == "$commit" ]] || die 'manifest commit mismatch'
  [[ $(jq -r '.windowTitle' "$file") == "$expected_title" ]] || die 'manifest title mismatch'
  printf '%s\n' "$pid"
}
acquire_lock() {
  if mkdir "$lock" 2>/dev/null; then printf '%s\n' "$$" > "$lock/pid"; return; fi
  local holder; holder=$(cat "$lock/pid" 2>/dev/null || true)
  if ! pid_is_live "$holder"; then rmdir "$lock" 2>/dev/null || die 'stale recursive lock needs diagnosis'; mkdir "$lock" || die 'could not acquire recursive lock'; printf '%s\n' "$$" > "$lock/pid"; return; fi
  die "another recursive validation coordinator is active (pid $holder)"
}
release_lock() { rm -f "$lock/pid"; rmdir "$lock" 2>/dev/null || true; }
write_run_json() {
  local state=$1 pid=${2:-null} now existing='{}'
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  mkdir -p "$(artifacts)"/{screenshots,telemetry,performance}
  [[ -f "$(artifacts)/run.json" ]] && existing=$(cat "$(artifacts)/run.json")
  jq -n --arg runID "$run_id" --arg branch "$(git branch --show-current)" --arg commit "$(git rev-parse HEAD)" \
    --arg bundle "$bundle" --arg support "$support_base/$run_id/agent-session-manager.dev" --arg artifacts "$(artifacts)" \
    --arg state "$state" --arg timestamp "$now" --argjson pid "$pid" --argjson existing "$existing" \
    '($existing + {schemaVersion:1,runID:$runID,branch:$branch,commit:$commit,bundlePath:$bundle,bundleID:"com.justinfuller.agent-session-manager.dev",pid:$pid,supportDirectory:$support,artifactDirectory:$artifacts,state:$state,updatedAt:$timestamp})
     | if $state == "starting" and .startedAt == null then .startedAt = $timestamp else . end
     | if $state == "ready" and .readyAt == null then .readyAt = $timestamp else . end
     | if $state == "failed" or $state == "stopped" then .exitClassification = $state else . end' \
    > "$(artifacts)/run.json"
}

case "$command" in
  start)
    require_jq
    if [[ -z $run_id ]]; then run_id=$(uuidgen | tr '[:upper:]' '[:lower:]'); fi
    [[ ! -e "$support_base/$run_id" ]] || die 'run support directory already exists'
    [[ ! -e "$(artifacts)" ]] || die 'run artifact directory already exists'
    acquire_lock; trap release_lock EXIT
    if pgrep -x AgentSessionManagerDev >/dev/null; then die 'an ordinary Dev instance is active; refusing to share its bundle'; fi
    write_run_json starting null
    if ! make app-dev; then
      write_run_json failed null
      die 'make app-dev failed; failed-run artifacts are preserved'
    fi
    open -n "$bundle" --args --recursive-development-run-id "$run_id"
    launched_pid=null
    write_run_json starting "$launched_pid"
    deadline=$((SECONDS + 30))
    until [[ -f $(manifest) ]] && [[ $(jq -r '.state' "$(manifest)") == ready ]]; do
      (( SECONDS < deadline )) || { write_run_json failed "$launched_pid"; die 'Dev launch did not become ready'; }
      sleep 1
    done
    verified_pid=$(verify_owned_manifest)
    pid_is_live "$verified_pid" || { write_run_json failed "$verified_pid"; die 'manifest process exited before verification'; }
    write_run_json ready "$verified_pid"
    (
      while pid_is_live "$verified_pid"; do
        ps -o %cpu= -o rss= -p "$verified_pid" | awk -v ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)" 'NF { printf "{\"timestamp\":\"%s\",\"cpuPercent\":%s,\"rssKB\":%s}\n", ts, $1, $2 }' >> "$(artifacts)/performance/samples.jsonl"
        sleep 1
      done
    ) &
    printf '%s\n' "$!" > "$(artifacts)/performance/sampler.pid"
    printf '%s\n' "$run_id"
    ;;
  status)
    require_jq; require_run
    pid=$(verify_owned_manifest)
    jq --argjson live "$(pid_is_live "$pid" && echo true || echo false)" '. + {processLive:$live}' "$(manifest)"
    ;;
  collect)
    require_jq; require_run
    mkdir -p "$(artifacts)"/{telemetry,performance,screenshots}
    cp "$(manifest)" "$(artifacts)/telemetry/runtime-manifest.json"
    support="$support_base/$run_id/agent-session-manager.dev"
    if [[ -n $tab || -n $pane ]]; then [[ -n $tab && -n $pane ]] || die '--tab and --pane must be paired'; fi
    if [[ -n $tab ]]; then
      .agents/skills/agent-data-access/scripts/collect-telemetry.sh --app dev --support-dir "$support_base/$run_id" --tab "$tab" --pane "$pane" --limit 200 > "$(artifacts)/telemetry/summary.json" || true
    else
      jq -n --arg support "$support" '{supportDirectory:$support,telemetry:"unverified: no pane selected"}' > "$(artifacts)/telemetry/summary.json"
    fi
    find "$support" -type f \( -path '*/traces/*.jsonl' -o -path '*/invariants/*.jsonl' \) -maxdepth 6 -print 2>/dev/null | head -200 > "$(artifacts)/telemetry/files.txt" || true
    /usr/bin/log show --style json --last 1h --predicate 'subsystem == "com.justinfuller.agent-session-manager.dev"' 2>/dev/null | head -c 1048576 > "$(artifacts)/telemetry/logs.jsonl" || true
    if [[ -f "$(artifacts)/performance/samples.jsonl" ]]; then
      jq -Rrc 'fromjson? | select(type == "object")' "$(artifacts)/performance/samples.jsonl" | jq -s '{sampleCount:length,cpuPercent:{min:([.[].cpuPercent]|min),max:([.[].cpuPercent]|max)},rssKB:{min:([.[].rssKB]|min),max:([.[].rssKB]|max)}}' > "$(artifacts)/performance/summary.json"
    else jq -n '{sampleCount:0,status:"unverified"}' > "$(artifacts)/performance/summary.json"; fi
    cat > "$(artifacts)/validation-report.md" <<EOF
# Recursive development validation report

Run: \`$run_id\`

| Area | Status | Evidence |
| --- | --- | --- |
| Visual | unverified | Save Computer Use screenshots under \`screenshots/\`. |
| Functional | unverified | Exercise the real UI flow. |
| Telemetry | unverified | \`telemetry/summary.json\` |
| Invariants | unverified | Inspect bounded telemetry files. |
| Automated tests | unverified | Retain focused Dev XCTest result. |
| Performance | unverified | \`performance/summary.json\`; no threshold applied. |
| Cleanup | unverified | Run \`stop\` only after collecting evidence. |
EOF
    ;;
  profile)
    require_run; [[ $seconds =~ ^[1-9][0-9]*$ ]] || die '--seconds must be a positive integer'
    command -v xctrace >/dev/null || die 'xctrace is unavailable; profiling is unverified'
    xctrace list templates | grep -Fq 'Time Profiler' || die 'Time Profiler template is unavailable; profiling is unverified'
    pid=$(verify_owned_manifest); mkdir -p "$(artifacts)/performance"
    xctrace record --template 'Time Profiler' --time-limit "$seconds" --attach "$pid" --output "$(artifacts)/performance/time-profiler.trace"
    ;;
  stop)
    require_jq; require_run
    pid=$(verify_owned_manifest)
    kill -TERM "$pid" || die 'graceful termination request failed; preserving diagnostics'
    deadline=$((SECONDS + 15)); while pid_is_live "$pid" && (( SECONDS < deadline )); do sleep 1; done
    if pid_is_live "$pid"; then die 'owned process did not exit gracefully; cleanup is unverified and state is preserved'; fi
    sampler="$(artifacts)/performance/sampler.pid"; [[ -f $sampler ]] && kill "$(cat "$sampler")" 2>/dev/null || true
    write_run_json stopped "$pid"
    # Evidence remains; only successful run persistence is removed after collection.
    [[ -f "$(artifacts)/validation-report.md" ]] || die 'collect evidence before deleting isolated persistence'
    rm -rf "$support_base/$run_id"
    sed -i '' 's#| Cleanup | unverified | Run `stop` only after collecting evidence\. |#| Cleanup | passed | Verified owned PID exited and isolated support was removed. |#' "$(artifacts)/validation-report.md"
    ;;
  *) usage ;;
esac
