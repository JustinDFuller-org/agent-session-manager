#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

if [ $# -ne 1 ]; then
    echo "usage: $0 <dmg-path>" >&2
    exit 1
fi

if [ -z "${SPARKLE_PRIVATE_KEY:-}" ]; then
    echo "ERROR: Set SPARKLE_PRIVATE_KEY to the base64 Sparkle EdDSA private key" >&2
    exit 1
fi

"$repo_root/scripts/validate-sparkle-key.sh"
"$repo_root/scripts/sparkle-tools.sh"
printf '%s' "$SPARKLE_PRIVATE_KEY" | \
    "$repo_root/.sparkle-tools/bin/sign_update" --ed-key-file - -p "$1"
