#!/usr/bin/env bash
# Ensures Sparkle CLI tools (generate_keys, sign_update) are available under
# .sparkle-tools/. Downloads a pinned Sparkle release on first run.
set -euo pipefail

readonly SPARKLE_VERSION="2.6.4"
readonly TOOLS_DIR=".sparkle-tools"

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

die() { echo "ERROR: $*" >&2; exit 1; }

if [ -f "$TOOLS_DIR/bin/sign_update" ] && [ -f "$TOOLS_DIR/bin/generate_keys" ]; then
    exit 0
fi

mkdir -p "$TOOLS_DIR"
tmp_tar="$TOOLS_DIR/Sparkle-$SPARKLE_VERSION.tar.xz"
curl -fsSL -o "$tmp_tar" "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
tar -xf "$tmp_tar" -C "$TOOLS_DIR" --strip-components=1
rm -f "$tmp_tar"

[ -f "$TOOLS_DIR/bin/sign_update" ] || die "sign_update not found after extracting Sparkle"
[ -f "$TOOLS_DIR/bin/generate_keys" ] || die "generate_keys not found after extracting Sparkle"
