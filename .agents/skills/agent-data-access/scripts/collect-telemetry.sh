#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: collect-telemetry.sh --app <prod|dev> [--list]
       [--tab <name> --pane <name> | --pane-id <uuid-or-prefix>]
       [--since <1h|24h|epoch-ms|RFC3339>] [--until <epoch-ms|RFC3339>]
       [--limit <count>] [--support-dir <path>]
EOF
  exit 2
}

die() {
  printf 'collect-telemetry.sh: %s\n' "$*" >&2
  exit 2
}

epoch_ms() {
  local value=$1 seconds
  if [[ $value =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$value"
    return
  fi
  if seconds=$(TZ=UTC date -j -f '%Y-%m-%dT%H:%M:%SZ' "$value" '+%s' 2>/dev/null); then
    printf '%s000\n' "$seconds"
    return
  fi
  if [[ $value =~ ^(.*)([+-][0-9][0-9]):([0-9][0-9])$ ]] &&
    seconds=$(date -j -f '%Y-%m-%dT%H:%M:%S%z' "${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}" '+%s' 2>/dev/null)
  then
    printf '%s000\n' "$seconds"
    return
  fi
  if seconds=$(TZ=UTC date -d "$value" '+%s' 2>/dev/null); then
    printf '%s000\n' "$seconds"
    return
  fi
  die "invalid time: $value"
}

app=
list=false
tab=
pane=
pane_id=
since=1h
until=
limit=200
support_dir="${HOME}/Library/Application Support"

while (($#)); do
  case "$1" in
    --app) (($# >= 2)) || usage; app=$2; shift 2 ;;
    --list) list=true; shift ;;
    --tab) (($# >= 2)) || usage; tab=$2; shift 2 ;;
    --pane) (($# >= 2)) || usage; pane=$2; shift 2 ;;
    --pane-id) (($# >= 2)) || usage; pane_id=$2; shift 2 ;;
    --since) (($# >= 2)) || usage; since=$2; shift 2 ;;
    --until) (($# >= 2)) || usage; until=$2; shift 2 ;;
    --limit) (($# >= 2)) || usage; limit=$2; shift 2 ;;
    --support-dir) (($# >= 2)) || usage; support_dir=$2; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $app == prod || $app == dev ]] || die "--app must be prod or dev"
[[ $limit =~ ^[1-9][0-9]*$ ]] || die "--limit must be a positive integer"
if [[ $list != true && -z $pane_id && ( -z $tab || -z $pane ) ]]; then
  die "select a pane with --tab <name> --pane <name> or --pane-id <uuid-or-prefix>, or use --list"
fi
if [[ -n $pane_id && ( -n $tab || -n $pane ) ]]; then
  die "--pane-id cannot be combined with --tab or --pane"
fi
if [[ -n $tab && -z $pane || -z $tab && -n $pane ]]; then
  die "--tab and --pane must be used together"
fi

subdir=agent-session-manager
[[ $app == dev ]] && subdir=agent-session-manager.dev
base="${support_dir%/}/$subdir"
traces="$base/traces"
sessions="$base/sessions.json"
debug_settings="$base/debug-settings.json"
invariants="$base/invariants/invariants.jsonl"

now_ms=$(( $(date '+%s') * 1000 ))
if [[ $since =~ ^([0-9]+)([hm])$ ]]; then
  amount=${BASH_REMATCH[1]}
  multiplier=3600000
  [[ ${BASH_REMATCH[2]} == m ]] && multiplier=60000
  since_ms=$(( now_ms - amount * multiplier ))
else
  since_ms=$(epoch_ms "$since")
fi
until_ms=$now_ms
[[ -n $until ]] && until_ms=$(epoch_ms "$until")
(( since_ms <= until_ms )) || die "--since must not be later than --until"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/agent-session-manager-telemetry.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
: > "$tmp/candidates.jsonl"
: > "$tmp/pane-spans.jsonl"
: > "$tmp/global-spans.jsonl"
: > "$tmp/invariants.jsonl"
: > "$tmp/malformed.jsonl"

json_file_array() {
  local file=$1
  if [[ -s $file ]]; then jq -s '.' "$file"; else printf '[]'; fi
}

record_malformed_count() {
  local path=$1 count=$2
  (( count > 0 )) || return 0
  jq -cn --arg path "$path" --argjson count "$count" '{path:$path,count:$count}' >> "$tmp/malformed.jsonl"
}

read_header() {
  local file=$1
  jq -Rrc 'fromjson? | select(._type == "metadata")' "$file" 2>/dev/null | head -n 1
}

matches_header() {
  local metadata=$1
  if [[ -n $pane_id ]]; then
    jq -e --arg id "$pane_id" '(.paneId | ascii_downcase) | startswith($id | ascii_downcase)' <<<"$metadata" >/dev/null
  elif [[ -n $tab ]]; then
    jq -e --arg tab "$tab" --arg pane "$pane" '.tabName == $tab and .paneName == $pane' <<<"$metadata" >/dev/null
  else
    return 0
  fi
}

if [[ -d $traces ]]; then
  while IFS= read -r -d '' file; do
    [[ $file == "$traces/_global/global.jsonl" ]] && continue
    metadata=$(read_header "$file" || true)
    [[ -n $metadata ]] || continue
    if matches_header "$metadata"; then
      jq -cn --arg path "$file" --argjson metadata "$metadata" '{path:$path,metadata:$metadata}' >> "$tmp/candidates.jsonl"
    fi
  done < <(find "$traces" -type f -name '*.jsonl' -print0 2>/dev/null | sort -z)
fi

candidate_files=$(json_file_array "$tmp/candidates.jsonl")
candidate_ids=$(jq -c '[.[].metadata.paneId]' <<<"$candidate_files")

session_matches='[]'
if [[ -f $sessions ]] && jq -e . "$sessions" >/dev/null 2>&1; then
  session_matches=$(
    jq -c \
      --arg tab "$tab" --arg pane "$pane" --arg paneId "$pane_id" \
      --argjson list "$list" \
      '[.tabs[]? as $tabRow |
        $tabRow.panes[]? |
        select(
          if $list then true
          elif $paneId != "" then (.id | ascii_downcase | startswith($paneId | ascii_downcase))
          else $tabRow.name == $tab and .name == $pane
          end
        ) |
        {tabId:$tabRow.id,tabName:$tabRow.name,tabDirectory:$tabRow.directory,paneId:.id,paneName:.name,harness:.harness,worktreeDirectory:.worktreeDirectory}]' \
      "$sessions"
  )
fi

if [[ $list != true ]]; then
  while IFS= read -r file; do
    [[ -n $file ]] || continue
    malformed=$(jq -Rrc 'select(length > 0) | select((fromjson? // null) == null)' "$file" | wc -l | tr -d ' ')
    record_malformed_count "$file" "$malformed"
    jq -Rrc \
      --argjson since "$since_ms" --argjson until "$until_ms" \
      'fromjson? | select(._type != "metadata") |
       select((.startEpochMs // 0) >= $since and (.startEpochMs // 0) <= $until)' \
      "$file" >> "$tmp/pane-spans.jsonl"
  done < <(jq -r '.[].path' <<<"$candidate_files")

  global_file="$traces/_global/global.jsonl"
  if [[ -f $global_file ]]; then
    malformed=$(jq -Rrc 'select(length > 0) | select((fromjson? // null) == null)' "$global_file" | wc -l | tr -d ' ')
    record_malformed_count "$global_file" "$malformed"
    jq -Rrc \
      --argjson since "$since_ms" --argjson until "$until_ms" \
      'fromjson? | select(._type != "metadata") |
       select((.startEpochMs // 0) >= $since and (.startEpochMs // 0) <= $until)' \
      "$global_file" >> "$tmp/global-spans.jsonl"
  fi

  if [[ -f $invariants ]]; then
    malformed=$(jq -Rrc 'select(length > 0) | select((fromjson? // null) == null)' "$invariants" | wc -l | tr -d ' ')
    record_malformed_count "$invariants" "$malformed"
    jq -Rrc \
      --argjson ids "$candidate_ids" --argjson since "$since_ms" --argjson until "$until_ms" \
      'fromjson? | select(._type != "metadata") |
       (try (.timestamp | fromdateiso8601 * 1000) catch null) as $timestamp |
       select($timestamp >= $since and $timestamp <= $until) |
       select(.context["pane.id"] as $id | $ids | index($id))' \
      "$invariants" >> "$tmp/invariants.jsonl"
  fi
fi

debug_mode=$(
  if [[ -f $debug_settings ]] && jq -e . "$debug_settings" >/dev/null 2>&1; then
    jq -c --arg path "$debug_settings" '{settingsFile:$path,exists:true,enabled:(.enabled == true),raw:.}' "$debug_settings"
  else
    jq -cn --arg path "$debug_settings" '{settingsFile:$path,exists:false,enabled:false,raw:null}'
  fi
)

legacy_debug_exists=false
legacy_debug_bytes=0
legacy_traces_exists=false
legacy_traces_bytes=0
if [[ -f "$base/debug-trace.log" ]]; then
  legacy_debug_exists=true
  legacy_debug_bytes=$(wc -c < "$base/debug-trace.log" | tr -d ' ')
fi
if [[ -f "$base/traces.jsonl" ]]; then
  legacy_traces_exists=true
  legacy_traces_bytes=$(wc -c < "$base/traces.jsonl" | tr -d ' ')
fi
legacy=$(
  jq -cn --arg base "$base" \
    --argjson debugExists "$legacy_debug_exists" --argjson debugBytes "$legacy_debug_bytes" \
    --argjson tracesExists "$legacy_traces_exists" --argjson tracesBytes "$legacy_traces_bytes" '
    [
      {path:($base + "/debug-trace.log"),exists:$debugExists,bytes:$debugBytes},
      {path:($base + "/traces.jsonl"),exists:$tracesExists,bytes:$tracesBytes}
    ]'
)

pane_count=$(wc -l < "$tmp/pane-spans.jsonl" | tr -d ' ')
global_count=$(wc -l < "$tmp/global-spans.jsonl" | tr -d ' ')
invariant_count=$(wc -l < "$tmp/invariants.jsonl" | tr -d ' ')

jq -n \
  --arg app "$app" --arg supportDirectory "$base" \
  --argjson list "$list" --arg tab "$tab" --arg pane "$pane" --arg paneId "$pane_id" \
  --argjson since "$since_ms" --argjson until "$until_ms" --argjson limit "$limit" \
  --argjson debugMode "$debug_mode" \
  --argjson sessionMatches "$session_matches" \
  --argjson candidateTraceFiles "$candidate_files" \
  --argjson legacyFiles "$legacy" \
  --slurpfile paneSpans "$tmp/pane-spans.jsonl" \
  --slurpfile invariantViolations "$tmp/invariants.jsonl" \
  --slurpfile correlatedGlobalSpans "$tmp/global-spans.jsonl" \
  --slurpfile malformedLines "$tmp/malformed.jsonl" \
  --argjson paneCount "$pane_count" --argjson globalCount "$global_count" --argjson invariantCount "$invariant_count" '
  {
    app:$app,
    supportDirectory:$supportDirectory,
    debugMode:$debugMode,
    query:{list:$list,tab:(if $tab == "" then null else $tab end),pane:(if $pane == "" then null else $pane end),paneId:(if $paneId == "" then null else $paneId end),sinceEpochMs:$since,untilEpochMs:$until,limit:$limit},
    currentSessionMatches:$sessionMatches,
    candidateTraceFiles:$candidateTraceFiles,
    paneSpans:($paneSpans | sort_by(.startEpochMs) | .[-$limit:]),
    matchingInvariantViolations:($invariantViolations | sort_by(.timestamp) | .[-$limit:]),
    correlatedGlobalSpans:($correlatedGlobalSpans | sort_by(.startEpochMs) | .[-$limit:]),
    truncation:{paneSpans:($paneCount > $limit),matchingInvariantViolations:($invariantCount > $limit),correlatedGlobalSpans:($globalCount > $limit)},
    malformedLines:$malformedLines,
    legacyFiles:$legacyFiles
  }'
