#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
site_dir="$repo_root/.build/docs-site"

cd "$repo_root"
rm -rf "$site_dir"
ruby scripts/check-docs-taxonomy.rb

bundle exec jekyll build --destination "$site_dir" --trace

bundle exec htmlproofer "$site_dir" \
  --disable-external \
  --ignore-urls '/downloads/AgentSessionManager-latest.dmg' \
  --directory-index-file index.html

external_urls=$(rg -g '*.html' -o --no-filename 'https?://[^"< ]+' "$site_dir" 2>/dev/null | sed 's/[),.]$//' | sort -u || true)
if [[ -n "$external_urls" ]]; then
  while IFS= read -r url; do
    [[ -z "$url" ]] || echo "warning: external URL not checked: $url"
  done <<< "$external_urls"
fi

for path in \
  "$site_dir/documentation/features" \
  "$site_dir/AGENTS.html" \
  "$site_dir/CLAUDE.html" \
  "$site_dir/USER_FACING_DOCS.html"; do
  if [[ -e "$path" ]]; then
    echo "error: internal documentation was rendered: ${path#$site_dir/}" >&2
    exit 1
  fi
done

echo "Documentation build and internal-link checks passed."
