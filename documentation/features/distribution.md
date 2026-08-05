# Distribution

Agent Session Manager is distributed as a **notarized Developer ID-signed DMG** hosted on the public GitHub Pages site. A private GitHub Release is also created for maintainer archives. It is not distributed through the Mac App Store or TestFlight for macOS.

## Why Not the Mac App Store or TestFlight

The Mac App Store and TestFlight for macOS require the App Sandbox to be enabled. Agent Session Manager is not sandboxed — its core workflow spawns external processes (`/bin/zsh`, `/usr/bin/git`, `/usr/bin/python3`, and the user-installed `claude`/`cursor`/`codex` CLIs). Enabling the App Sandbox would break worktree creation, terminal pane harness launches, status-line shell scripts, and most other features.

The app uses the existing `AgentSessionManager.entitlements` file only to record the automation Apple Events entitlement; it does not enable the App Sandbox.

Released DMGs use Sparkle for update checks. GitHub PR tracking still requires the user-installed, authenticated GitHub CLI; Finder launches use the app's sanitized environment so standard CLI locations and GitHub CLI configuration remain available.

## Distribution Pipeline

The shippable artifact is produced by:

```bash
make dist
```

This builds the `.app` bundle (via the existing `make app` SPM-based flow),
embeds `Sparkle.framework` under `Contents/Frameworks` and the Agent Control MCP
bridge under `Contents/Helpers`, then re-signs and packages it through
`scripts/dist.sh`:

1. Stamps a version into `Info.plist`.
2. Re-signs the `.app` with the **Developer ID Application** certificate, the entitlements file, and hardened runtime.
3. Builds a compressed DMG containing the `.app` and an `Applications` symlink.
4. Submits the DMG to Apple for notarization.
5. Staples the notarization ticket to the DMG.
6. Validates the result with `spctl --assess --type install`.

The standalone bundle check is available before a release build:

```bash
make test-app-bundles
```

It verifies that both production and development app bundles contain Sparkle
and the executable `AgentSessionManagerMCPBridge`, resolve the framework through
the app bundle rpath, and have valid app and nested-helper signatures.

The DMG is written next to the `.app` bundle at the git common root, named:

```
AgentSessionManager-<short-version>-<build-number>.dmg
```

For example:

```
AgentSessionManager-0.0.1-197.dmg
```

### Version Stamping

`make dist` derives version numbers from git state and the published Sparkle appcast:

- `CFBundleShortVersionString` comes from the latest git tag with the leading `v` removed. If no tag exists, it falls back to `0.0.1`.
- `CFBundleVersion` is the greater of `git rev-list --count HEAD` and one above the highest build published in the public Sparkle appcast. The appcast is the authoritative release sequence, so the number remains monotonic across divergent branches and merge strategies.

Create the first release tag before running `make dist`:

```bash
git tag v0.0.1
```

### Developer ID vs. Daily Development

`make app` and `make run` remain unchanged for daily development. They build an ad-hoc-signed `.app` that uses the same bundle identifier (`com.justinfuller.agent-session-manager`) as the distributed build, so both read from and write to the same `~/Library/Application Support/agent-session-manager/` directory. The only difference is the code signature and the notarization wrapper.

## One-Time Prerequisites

Before the first `make dist`, set up:

1. A **Developer ID Application** certificate in the Apple Developer portal (not the iOS Distribution / App Store certificate).
2. An app-specific password at [appleid.apple.com](https://appleid.apple.com).
3. Store the notarization credentials in your Keychain:

   ```bash
   xcrun notarytool store-credentials "AC_NOTARY" \
     --apple-id <your-apple-id> \
     --team-id CX2KMQZQ7X \
     --password <app-specific-password>
   ```

4. Confirm the profile works:

   ```bash
   xcrun notarytool history --keychain-profile AC_NOTARY
   ```

These credentials are stored locally and never committed to the repository.

## Publishing a Release

The release workflow publishes the DMG to GitHub Pages after `make dist` succeeds. It also creates a private GitHub Release for maintainers. The public download page is:

[https://agent-session-manager.justindfuller.com/download/](https://agent-session-manager.justindfuller.com/download/)

The Pages deployment contains the latest DMG and the signed Sparkle appcast. DMGs are release artifacts, not tracked Git files or Git LFS objects.

For GitHub Actions releases, configure the `release` environment with `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `DEV_ID_CERTIFICATE_BASE64`, `DEV_ID_CERTIFICATE_PASSWORD`, and `SPARKLE_PRIVATE_KEY`. The Apple app-specific password is created from the Apple Account used for notarization; it is not the normal Apple Account password. Local releases may continue using the `AC_NOTARY` keychain profile.

### Publishing Locally When Actions Are Unavailable

The normal release workflow deploys a Pages artifact through GitHub Actions. There is no supported local command that uploads that workflow artifact directly. When Actions minutes are unavailable, publish a prebuilt static site from a dedicated `gh-pages` branch instead.

#### Documentation-only publication

For documentation changes, use the local Jekyll build and preserve the current
release assets. This does not build, sign, notarize, or publish a new DMG.

From the source checkout:

```bash
set -euo pipefail

publish_root=$(mktemp -d -t agent-session-manager-pages.XXXXXX)
site_dir="$publish_root/site"
branch_dir="$publish_root/branch"

make docs-check
bundle exec jekyll build --destination "$site_dir" --trace
scripts/stage-pages-assets.sh "$site_dir" preserve
cp CNAME "$site_dir/CNAME"
touch "$site_dir/.nojekyll"
```

`preserve` downloads the current public appcast and the DMG named by its latest
appcast enclosure. If the public appcast has no release item, the resulting
site contains no DMG, which is valid for a documentation-only publication.

Before publishing, verify the new route and the internal-documentation
boundary:

```bash
test -f "$site_dir/documentation/user-guide/agent-control/index.html"
test ! -e "$site_dir/AGENTIC_CONTROL.md"
test ! -e "$site_dir/AgentSessionManager.xcodeproj"
test ! -e "$site_dir/Info.plist"
test ! -e "$site_dir/default.profraw"
test ! -e "$site_dir/documentation/agent-control-mcp-qa-findings.md"
test ! -e "$site_dir/documentation/features"
```

Replace the rendered contents of a temporary `gh-pages` checkout. Preserve its
existing `downloads/` directory before replacing the rest of the branch so
older release files remain available:

```bash
remote_url=$(git remote get-url origin)

git clone --branch gh-pages --single-branch "$remote_url" "$branch_dir"
if test -d "$branch_dir/downloads"; then
    cp -R "$branch_dir/downloads" "$site_dir/downloads"
fi

find "$branch_dir" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R "$site_dir"/. "$branch_dir"/

git -C "$branch_dir" add --all
git -C "$branch_dir" commit -m "Publish documentation site from $(git rev-parse --short HEAD)"
git -C "$branch_dir" push origin gh-pages
```

Configure Pages once before the first branch publication. The API equivalent
of **Settings → Pages → Deploy from a branch → gh-pages → /(root)** is:

```bash
gh api --method PUT repos/JustinDFuller/agent-session-manager/pages \
    -f build_type=legacy \
    -f 'source[branch]=gh-pages' \
    -f 'source[path]=/'
```

Keep the custom domain and HTTPS enforcement enabled. If the first branch push
was made before switching Pages from workflow mode to legacy mode, push a
follow-up commit to `gh-pages` to trigger the initial legacy build.

Verify the branch, Pages build, public route, and preserved release endpoints:

```bash
gh api repos/JustinDFuller/agent-session-manager/pages \
    --jq '{build_type,source,cname,https_enforced,status}'
gh api repos/JustinDFuller/agent-session-manager/pages/builds/latest \
    --jq '{status,commit,updated_at,error_message}'
curl --fail --location --head \
    https://agent-session-manager.justindfuller.com/documentation/user-guide/agent-control/
curl --fail --silent \
    https://agent-session-manager.justindfuller.com/appcast.xml
```

GitHub Pages must be configured to deploy from the `gh-pages` branch at the repository root. The branch contains only the rendered site, the signed appcast, and release DMGs. The `.nojekyll` marker tells Pages that the site has already been built locally.

Before the first local publication:

1. In **Settings → Pages**, select **Deploy from a branch**, choose `gh-pages`, choose `/(root)`, and save.
2. Keep the custom domain `agent-session-manager.justindfuller.com` and HTTPS enforcement enabled.
3. Disable the repository's Pages deployment workflows after the branch source is active so an Actions deployment cannot overwrite a local publication.
4. Confirm the local release credentials without printing their values:

   ```bash
   security find-identity -v -p codesigning
   xcrun notarytool history --keychain-profile AC_NOTARY
   test -f .sparkle/sparkle-private.pem
   gh auth status
   ```

The Sparkle private key is required to sign the appcast. It must never be committed:

```bash
export SPARKLE_PRIVATE_KEY="$(cat .sparkle/sparkle-private.pem)"
```

For each local publication, build and notarize the DMG first:

```bash
make dist
```

Set `dmg_path` to the resulting `AgentSessionManager-<short-version>-<build-number>.dmg`. Then render the site, generate the signed appcast, and stage the release assets:

```bash
set -euo pipefail

publish_root=$(mktemp -d -t agent-session-manager-pages.XXXXXX)
site_dir="$publish_root/site"
base_appcast="$publish_root/base-appcast.xml"
release_appcast="$publish_root/release-appcast.xml"
dmg_path="/absolute/path/to/AgentSessionManager-<short-version>-<build-number>.dmg"

source scripts/release-config.sh
bundle exec jekyll build --destination "$site_dir" --trace

if ! curl --fail --silent --show-error --location \
    "$PUBLIC_APPCAST_URL" --output "$base_appcast"; then
    cp appcast.xml "$base_appcast"
fi

dmg_name=$(basename "$dmg_path")
version_short=${dmg_name#AgentSessionManager-}
version_short=${version_short%-*.dmg}
version_build=${dmg_name#AgentSessionManager-${version_short}-}
version_build=${version_build%.dmg}

APPCAST_BASE="$base_appcast" \
APPCAST_OUTPUT="$release_appcast" \
    scripts/update-appcast.sh "$dmg_path" "$version_short" "$version_build"

scripts/stage-pages-assets.sh \
    "$site_dir" release "$dmg_path" "$release_appcast"
cp CNAME "$site_dir/CNAME"
touch "$site_dir/.nojekyll"
```

Use a temporary checkout of `gh-pages` for publication so the source checkout is not changed. If the branch already exists, preserve its `downloads/` directory so older appcast entries continue to resolve:

```bash
remote_url=$(git remote get-url origin)
branch_dir="$publish_root/branch"

if git ls-remote --exit-code --heads "$remote_url" gh-pages >/dev/null 2>&1; then
    git clone --branch gh-pages --single-branch "$remote_url" "$branch_dir"
    if test -d "$branch_dir/downloads"; then
        cp -R "$branch_dir/downloads" "$site_dir/downloads"
    fi
else
    mkdir -p "$branch_dir"
    git -C "$branch_dir" init
    git -C "$branch_dir" branch -M gh-pages
    git -C "$branch_dir" remote add origin "$remote_url"
fi

find "$branch_dir" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R "$site_dir"/. "$branch_dir"/

git -C "$branch_dir" add --all
git -C "$branch_dir" commit -m "Publish Agent Session Manager $version_short"
git -C "$branch_dir" push origin gh-pages
```

Verify the publication before sharing it:

```bash
gh api repos/JustinDFuller/agent-session-manager/pages \
    --jq '{build_type,source,cname,https_enforced}'
gh api repos/JustinDFuller/agent-session-manager/pages/builds/latest \
    --jq '{status,commit,updated_at}'
curl --fail --location --head \
    https://agent-session-manager.justindfuller.com/downloads/AgentSessionManager-latest.dmg
curl --fail --silent \
    https://agent-session-manager.justindfuller.com/appcast.xml
```

The Pages source should report the `gh-pages` branch and `/` path. The latest DMG, its versioned filename, and every appcast enclosure should return successfully. Keep the branch below GitHub Pages' published-site size limit, and prune obsolete versioned DMGs if the release history grows substantially.

## First-Distribution Verification Checklist

- [ ] `make dist` completes without errors.
- [ ] `make test-app-bundles` passes before building the DMG.
- [ ] `spctl --assess --verbose=4 --type install AgentSessionManager-<ver>-<build>.dmg` reports `accepted`.
- [ ] The mounted DMG opens correctly and contains the app plus an `Applications` shortcut.
- [ ] After dragging to `/Applications`, the app launches and can open a pane that spawns a harness (Claude Code, Cursor, or Codex).
- [ ] Worktree creation under `.agent-session-manager/worktrees/` still works.
- [ ] The status line shows data for a running pane.

## Update Reminders

Released DMG builds check for new versions using Sparkle against a public `appcast.xml` hosted by this repository's GitHub Pages site. Source-built and ad-hoc-signed builds keep the existing GitHub API check against `main` instead, because they do not carry a stable release channel.

`scripts/dist.sh` configures the Sparkle feed and EdDSA signing keys as part of every release build:

- Strips `ASMSource*` keys from `Info.plist` and writes `ASMDistributionChannel` = `dmg`.
- Injects the public Sparkle EdDSA key into `Info.plist` as `SUFeedPublicEdKey`.
- Writes the public Pages feed URL into `Info.plist` as `SUFeedURL`.
- The release workflow signs the DMG with the private EdDSA key and publishes the resulting item to the Pages-hosted `appcast.xml`.

Source / development builds never set `ASMDistributionChannel`, so `UpdateCheckCoordinator` routes them to `MainBranchUpdateDetector` and `DMGReleaseDetector` is never initialized.

For full details on the detector routing and the update UI, see [update-reminder.md]({{ '/documentation/features/update-reminder/' | relative_url }}).

### Environment differences between `make run` and a Finder/DMG launch

`make run` launches the app from your shell, so the app inherits a full environment: the parent shell's `PATH` (including Homebrew, `go`, nvm, etc.) and a `TERM` value set by the terminal emulator.

Opening the app from Finder or the DMG gives it the minimal environment that LaunchServices provides. Without adjustment, spawned panes can see a bare `PATH` and no `TERM`, which may cause tools like Claude Code to render without color and may surface warnings from `~/.zshrc` that reference tools not yet on `PATH`.

The app handles this by sanitizing each pane's environment before it starts (see [panes.md]({{ '/documentation/features/panes/' | relative_url }})). When verifying a distribution build, confirm that panes still spawn cleanly and that Claude/Cursor/Codex render color output as expected.
