#!/usr/bin/env bash
# Appends a new release item to appcast.xml for the freshly built DMG.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

if [ $# -ne 3 ]; then
    echo "usage: $0 <dmg-path> <short-version> <build-number>" >&2
    exit 1
fi

dmg_path=$1
version_short=$2
version_build=$3
tag="v$version_short"
dmg_name=$(basename "$dmg_path")
release_url="https://github.com/JustinDFuller/agent-session-manager/releases/download/$tag/$dmg_name"

if [ ! -f "$dmg_path" ]; then
    echo "ERROR: DMG not found: $dmg_path" >&2
    exit 1
fi

signature=$("$repo_root/scripts/sign-update.sh" "$dmg_path")
file_size=$(stat -f%z "$dmg_path")
pub_date=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
appcast="$repo_root/appcast.xml"

if [ ! -f "$appcast" ]; then
    echo "ERROR: appcast.xml not found at $appcast" >&2
    exit 1
fi

item="    <item>
      <title>Agent Session Manager $version_short</title>
      <pubDate>$pub_date</pubDate>
      <sparkle:version>$version_build</sparkle:version>
      <sparkle:shortVersionString>$version_short</sparkle:shortVersionString>
      <enclosure url=\"$release_url\" length=\"$file_size\" type=\"application/octet-stream\" sparkle:edSignature=\"$signature\" />
    </item>"

awk -v item="$item" '/<\/channel>/{print item} {print}' "$appcast" > "$appcast.tmp"
mv "$appcast.tmp" "$appcast"

echo "Updated $appcast with $tag"
