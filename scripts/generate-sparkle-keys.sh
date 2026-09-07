#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

bash "$repo_root/scripts/sparkle-tools.sh"

keys_dir=".sparkle"
mkdir -p "$keys_dir"

"$repo_root/.sparkle-tools/bin/generate_keys" > "$keys_dir/sparkle-public.pem"
"$repo_root/.sparkle-tools/bin/generate_keys" -x "$keys_dir/sparkle-private.pem"

public_key=$(sed -n 's/.*<string>\([^<]*\)<\/string>.*/\1/p' "$keys_dir/sparkle-public.pem")
if [ -z "$public_key" ]; then
    echo "ERROR: Could not extract the Sparkle public key" >&2
    exit 1
fi
printf '%s\n' "$public_key" > "$keys_dir/sparkle-public.pem"

echo
echo "Add this public key to Info.plist under SUPublicEdKey (or let dist.sh read it from $keys_dir/sparkle-public.pem):"
cat "$keys_dir/sparkle-public.pem"
echo
echo "For CI/appcast signing, set SPARKLE_PRIVATE_KEY to the contents of $keys_dir/sparkle-private.pem"
