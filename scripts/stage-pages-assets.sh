#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/scripts/release-config.sh"

if [[ $# -lt 2 ]]; then
    echo "usage: $0 <site-directory> <release|preserve> [dmg-path appcast-path]" >&2
    exit 1
fi

site_dir=$1
mode=$2
downloads_dir="$site_dir/$PUBLIC_DOWNLOADS_PATH"
mkdir -p "$downloads_dir"

stage_release() {
    if [[ $# -ne 2 ]]; then
        echo "usage: $0 <site-directory> release <dmg-path> <appcast-path>" >&2
        exit 1
    fi

    local dmg_path=$1
    local appcast_path=$2
    local dmg_name
    dmg_name=$(basename "$dmg_path")

    [[ -f "$dmg_path" ]] || { echo "DMG not found: $dmg_path" >&2; exit 1; }
    [[ -f "$appcast_path" ]] || { echo "appcast not found: $appcast_path" >&2; exit 1; }

    cp "$dmg_path" "$downloads_dir/$dmg_name"
    cp "$dmg_path" "$downloads_dir/AgentSessionManager-latest.dmg"
    cp "$appcast_path" "$site_dir/appcast.xml"
}

stage_preserved_release() {
    local current_appcast="$site_dir/appcast.xml"
    local enclosure_url
    local asset_name

    curl --fail --silent --show-error --location "$PUBLIC_APPCAST_URL" \
        --output "$current_appcast"

    read -r enclosure_url asset_name < <(
        ruby -ruri -rrexml/document -e '
          path = ARGV.fetch(0)
          site_host = URI(ARGV.fetch(1)).host
          document = REXML::Document.new(File.read(path))
          enclosure = document.elements.to_a("rss/channel/item/enclosure").last
          exit 0 unless enclosure
          url = URI(enclosure.attributes.fetch("url").to_s)
          abort "appcast enclosure must use the public Pages host" unless url.scheme == "https" && url.host == site_host
          puts "#{url} #{File.basename(url.path)}"
        ' "$current_appcast" "$PUBLIC_SITE_URL"
    )

    if [[ -z "${enclosure_url:-}" || -z "${asset_name:-}" ]]; then
        return 0
    fi

    curl --fail --silent --show-error --location "$enclosure_url" \
        --output "$downloads_dir/$asset_name"
    cp "$downloads_dir/$asset_name" "$downloads_dir/AgentSessionManager-latest.dmg"
}

case "$mode" in
    release)
        stage_release "${3:-}" "${4:-}"
        ;;
    preserve)
        stage_preserved_release
        ;;
    *)
        echo "unknown mode: $mode" >&2
        exit 1
        ;;
esac
