#!/usr/bin/env bash
# Generate the EdDSA key pair used to sign appcast updates and verify them in
# the distributed app. Run once per machine/CI environment; keep the private
# key secret.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

"$repo_root/scripts/sparkle-tools.sh"

keys_dir=".sparkle"
mkdir -p "$keys_dir"

"$repo_root/.sparkle-tools/bin/generate_keys" -f "$keys_dir/sparkle-private.pem" -p "$keys_dir/sparkle-public.pem"

echo
echo "Add this public key to Info.plist under SUPublicEdKey (or let dist.sh read it from $keys_dir/sparkle-public.pem):"
cat "$keys_dir/sparkle-public.pem"
echo
echo "For CI/appcast signing, set SPARKLE_PRIVATE_KEY to the contents of $keys_dir/sparkle-private.pem"
