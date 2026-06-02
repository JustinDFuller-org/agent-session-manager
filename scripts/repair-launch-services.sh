#!/usr/bin/env bash
set -euo pipefail

lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
prod_bundle="${1:?production bundle path is required}"
dev_bundle="${2:?dev bundle path is required}"
prod_id="com.justinfuller.agent-session-manager"
dev_id="com.justinfuller.agent-session-manager.dev"
dump="$(mktemp -t agent-session-manager-launch-services.XXXXXX)"
trap 'rm -f "$dump"' EXIT

"$lsregister" -dump > "$dump"

registered_paths() {
    local bundle_id="$1"
    awk -v bundle_id="$bundle_id" '
        /^path:[[:space:]]+/ {
            path = $0
            sub(/^path:[[:space:]]+/, "", path)
            sub(/[[:space:]]+\(0x[[:xdigit:]]+\)$/, "", path)
        }
        /^identifier:[[:space:]]+/ {
            identifier = $0
            sub(/^identifier:[[:space:]]+/, "", identifier)
        }
        /^-+$/ {
            if (identifier == bundle_id && path != "") print path
            path = ""
            identifier = ""
        }
        END {
            if (identifier == bundle_id && path != "") print path
        }
    ' "$dump"
}

for bundle_id in "$prod_id" "$dev_id"; do
    while IFS= read -r path; do
        [[ -z "$path" ]] || "$lsregister" -u "$path" 2>/dev/null || true
    done < <(registered_paths "$bundle_id")
done

verify_bundle() {
    local bundle_id="$1"
    local bundle_path="$2"
    [[ -d "$bundle_path" ]] || return 0
    "$lsregister" -f "$bundle_path"
    local resolved
    resolved="$(
        osascript -l JavaScript -e \
            "ObjC.import('AppKit'); ObjC.unwrap($.NSWorkspace.sharedWorkspace.URLForApplicationWithBundleIdentifier('$bundle_id').path)"
    )"
    if [[ "$resolved" != "$bundle_path" ]]; then
        printf 'Launch Services resolved %s to %s, expected %s\n' "$bundle_id" "$resolved" "$bundle_path" >&2
        return 1
    fi
    printf 'Launch Services resolves %s to %s\n' "$bundle_id" "$resolved"
}

verify_bundle "$prod_id" "$prod_bundle"
verify_bundle "$dev_id" "$dev_bundle"
