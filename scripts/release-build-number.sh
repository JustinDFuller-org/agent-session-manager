#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/scripts/release-config.sh"

if [[ $# -ne 1 || ! $1 =~ ^[0-9]+$ ]]; then
    echo "usage: $0 <git-build-count>" >&2
    exit 1
fi

git_build_count=$1
appcast_path=${RELEASE_APPCAST_PATH:-}
temporary_appcast=""

cleanup() {
    if [[ -n "$temporary_appcast" ]]; then
        rm -f "$temporary_appcast"
    fi
}
trap cleanup EXIT

if [[ -z "$appcast_path" ]]; then
    temporary_appcast=$(mktemp -t agent-session-manager-appcast.XXXXXX)
    curl --fail --silent --show-error --location "$PUBLIC_APPCAST_URL" --output "$temporary_appcast"
    appcast_path=$temporary_appcast
fi

[[ -f "$appcast_path" ]] || {
    echo "ERROR: appcast not found: $appcast_path" >&2
    exit 1
}

highest_published_build=$(ruby -rrexml/document -e '
  document = REXML::Document.new(File.binread(ARGV.fetch(0)))
  versions = document.elements.to_a("rss/channel/item/sparkle:version").filter_map(&:text)
  abort "appcast contains a non-numeric sparkle:version" unless versions.all? { |version| /\A\d+\z/.match?(version) }
  puts(versions.map(&:to_i).max || 0)
' "$appcast_path")

if (( git_build_count > highest_published_build )); then
    echo "$git_build_count"
else
    echo $((highest_published_build + 1))
fi
