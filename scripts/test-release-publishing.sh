#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=scripts/release-config.sh
source "$repo_root/scripts/release-config.sh"

test_root=$(mktemp -d -t agent-session-manager-release-test.XXXXXX)
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/site" "$test_root/input"
printf 'fixture-dmg' > "$test_root/input/AgentSessionManager-0.0.1-1.dmg"
cp "$repo_root/appcast.xml" "$test_root/input/appcast.xml"

"$repo_root/scripts/stage-pages-assets.sh" \
    "$test_root/site" release \
    "$test_root/input/AgentSessionManager-0.0.1-1.dmg" \
    "$test_root/input/appcast.xml"

cmp \
    "$test_root/site/downloads/AgentSessionManager-0.0.1-1.dmg" \
    "$test_root/site/downloads/AgentSessionManager-latest.dmg"
test -f "$test_root/site/appcast.xml"
test "$(git -C "$repo_root" ls-files '*.dmg')" = ""
if rg -n 'github\.com/JustinDFuller/agent-session-manager/releases|justinfuller\.github\.io' \
    "$repo_root/index.md" \
    "$repo_root/documentation/tutorials" \
    "$repo_root/documentation/how-to" \
    "$repo_root/documentation/reference" \
    "$repo_root/documentation/explanation" \
    "$repo_root/appcast.xml" \
    "$repo_root/scripts" \
    "$repo_root/documentation/features/distribution.md"; then
    echo "public release copy contains a private or obsolete URL" >&2
    exit 1
fi

echo "Release publication contract passed."
