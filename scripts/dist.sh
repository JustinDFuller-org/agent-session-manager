#!/usr/bin/env bash
# Build a notarized, Developer ID-signed DMG of Agent Session Manager for
# distribution outside the Mac App Store.
#
# Usage: scripts/dist.sh <path-to-AgentSessionManager.app>
#
# The script copies the input .app into a temporary staging area, stamps a
# unique version into its Info.plist, re-signs it with the Developer ID
# Application certificate, builds a DMG, submits the DMG to Apple for
# notarization, staples the resulting ticket, and validates the result.
#
# Prerequisites (one-time):
#   - Developer ID Application certificate installed in Keychain.
#   - App-specific password created at appleid.apple.com.
#   - Either a local "AC_NOTARY" keychain profile, or AC_NOTARY_APPLE_ID and
#     AC_NOTARY_PASSWORD environment variables for CI.
set -euo pipefail

readonly DEV_IDENTITY="Developer ID Application: Justin Fuller (CX2KMQZQ7X)"
readonly TEAM_ID="CX2KMQZQ7X"
readonly NOTARY_PROFILE="AC_NOTARY"
readonly ENTITLEMENTS_FILENAME="AgentSessionManager.entitlements"

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
# shellcheck source=scripts/release-config.sh
source "$repo_root/scripts/release-config.sh"

info() { echo "==> $*"; }
error() { echo "ERROR: $*" >&2; }
die() { error "$*"; exit 1; }

cleanup() {
  if [[ -n "${staging_dir:-}" && -d "$staging_dir" ]]; then
    rm -rf "$staging_dir"
  fi
}
trap cleanup EXIT

main() {
  if [[ $# -ne 1 ]]; then
    die "usage: $0 <path-to-AgentSessionManager.app>"
  fi

  local app_bundle app_bundle_name parent_dir
  app_bundle="$1"
  app_bundle_name=$(basename "$app_bundle")
  parent_dir=$(cd "$(dirname "$app_bundle")" && pwd)

  [[ -d "$app_bundle" ]] || die "app bundle not found: $app_bundle"
  [[ -f "$app_bundle/Contents/Info.plist" ]] || die "Info.plist missing in app bundle"

  local entitlements_path="$repo_root/$ENTITLEMENTS_FILENAME"
  [[ -f "$entitlements_path" ]] || die "entitlements file not found: $entitlements_path"

  security find-identity -v -p codesigning | grep -q "$DEV_IDENTITY" || \
    die "Developer ID identity not found in Keychain: $DEV_IDENTITY"

  local version_short version_build
  version_short=$(git -C "$repo_root" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
  version_short=${version_short:-0.0.1}
  local git_build_count
  git_build_count=$(git -C "$repo_root" rev-list --count HEAD 2>/dev/null || true)
  git_build_count=${git_build_count:-1}
  version_build=$("$repo_root/scripts/release-build-number.sh" "$git_build_count")

  info "Preparing distribution: $version_short ($version_build)"

  staging_dir=$(mktemp -d -t agent-session-manager-dist.XXXXXX)
  local staged_app="$staging_dir/$app_bundle_name"
  local staging_volume="$staging_dir/Agent Session Manager"

  cp -a "$app_bundle" "$staged_app"
  [[ -f "$staged_app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle" ]] || \
    die "Sparkle.framework is missing from the app bundle"
  [[ -x "$staged_app/Contents/Helpers/AgentSessionManagerMCPBridge" ]] || \
    die "Agent Control MCP bridge is missing from the app bundle"

  info "Stamping version into Info.plist"
  local info_plist="$staged_app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version_short" "$info_plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version_build" "$info_plist"

  info "Marking distribution channel as dmg"
  for key in ASMSourceCommit ASMSourceBranch ASMSourceCommitDate ASMDistributionChannel; do
    /usr/libexec/PlistBuddy -c "Delete :$key" "$info_plist" 2>/dev/null || true
  done
  /usr/libexec/PlistBuddy -c "Add :ASMDistributionChannel string dmg" "$info_plist"

  local sparkle_public_key_file="$repo_root/.sparkle/sparkle-public.pem"
  if [ -f "$sparkle_public_key_file" ]; then
    info "Injecting Sparkle feed URL and public key"
    local public_key
    public_key=$(cat "$sparkle_public_key_file")
    /usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$info_plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $PUBLIC_APPCAST_URL" "$info_plist"
    /usr/libexec/PlistBuddy -c "Delete :SUPublicEdKey" "$info_plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :SUPublicEdKey string $public_key" "$info_plist"
  else
    info "Sparkle public key not found at $sparkle_public_key_file; skipping feed injection"
  fi

  info "Signing app with Developer ID + entitlements + hardened runtime"
  codesign --force --deep \
    --sign "$DEV_IDENTITY" \
    --entitlements "$entitlements_path" \
    --options runtime \
    --timestamp \
    "$staged_app"

  codesign --verify --deep --verbose=2 "$staged_app" >/dev/null || \
    die "app signature verification failed"
  codesign --verify --strict \
    "$staged_app/Contents/Helpers/AgentSessionManagerMCPBridge" >/dev/null || \
    die "Agent Control MCP bridge signature verification failed"

  info "Building DMG"
  mkdir -p "$staging_volume"
  cp -a "$staged_app" "$staging_volume/"
  ln -s /Applications "$staging_volume/Applications"

  local dmg_base="AgentSessionManager-${version_short}-${version_build}"
  local dmg_path="$parent_dir/${dmg_base}.dmg"
  rm -f "$dmg_path"

  hdiutil create \
    -volname "Agent Session Manager" \
    -srcfolder "$staging_volume" \
    -fs HFS+ \
    -format UDZO \
    -o "$dmg_path" >/dev/null

  info "Submitting DMG to Apple for notarization"
  local -a notary_credentials
  if [[ -n "${AC_NOTARY_APPLE_ID:-}" && -n "${AC_NOTARY_PASSWORD:-}" ]]; then
    notary_credentials=(
      --apple-id "$AC_NOTARY_APPLE_ID"
      --team-id "$TEAM_ID"
      --password "$AC_NOTARY_PASSWORD"
    )
  else
    notary_credentials=(--keychain-profile "$NOTARY_PROFILE")
  fi
  xcrun notarytool submit "$dmg_path" \
    "${notary_credentials[@]}" \
    --wait || die "DMG notarization submission failed"

  info "Stapling notarization ticket to DMG"
  xcrun stapler staple "$dmg_path" || die "DMG stapling failed"
  xcrun stapler validate "$dmg_path" >/dev/null || die "DMG stapler validation failed"

  info "Mounting DMG and validating the app inside"
  local mount_point
  mount_point=$(mktemp -d -t agent-session-manager-dmg-mount.XXXXXX)
  hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse >/dev/null || \
    die "failed to mount DMG for validation"

  local mounted_app="$mount_point/AgentSessionManager.app"
  [[ -d "$mounted_app" ]] || {
    hdiutil detach "$mount_point" >/dev/null 2>&1 || true
    die "AgentSessionManager.app not found inside mounted DMG"
  }
  [[ -f "$mounted_app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle" ]] || {
    hdiutil detach "$mount_point" >/dev/null 2>&1 || true
    die "Sparkle.framework is missing from the mounted DMG"
  }
  [[ -x "$mounted_app/Contents/Helpers/AgentSessionManagerMCPBridge" ]] || {
    hdiutil detach "$mount_point" >/dev/null 2>&1 || true
    die "Agent Control MCP bridge is missing from the mounted DMG"
  }

  spctl --assess --type exec --verbose=4 "$mounted_app" || {
    hdiutil detach "$mount_point" >/dev/null 2>&1 || true
    die "app inside DMG failed Gatekeeper assessment"
  }

  hdiutil detach "$mount_point" >/dev/null || die "failed to unmount DMG after validation"

  echo
  echo "Distribution ready:"
  echo "  $dmg_path"
}

main "$@"
