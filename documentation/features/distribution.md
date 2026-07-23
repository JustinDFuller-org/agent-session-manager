# Distribution

Agent Session Manager is distributed as a **notarized Developer ID-signed DMG** hosted on the public GitHub Pages site. A private GitHub Release is also created for maintainer archives. It is not distributed through the Mac App Store or TestFlight for macOS.

## Why Not the Mac App Store or TestFlight

The Mac App Store and TestFlight for macOS require the App Sandbox to be enabled. Agent Session Manager is not sandboxed — its core workflow spawns external processes (`/bin/zsh`, `/usr/bin/git`, `/usr/bin/python3`, and the user-installed `claude`/`cursor`/`codex` CLIs). Enabling the App Sandbox would break worktree creation, terminal pane harness launches, status-line shell scripts, and most other features.

The app uses the existing `AgentSessionManager.entitlements` file only to record the automation Apple Events entitlement; it does not enable the App Sandbox.

## Distribution Pipeline

The shippable artifact is produced by:

```bash
make dist
```

This builds the `.app` bundle (via the existing `make app` SPM-based flow), then re-signs and packages it through `scripts/dist.sh`:

1. Stamps a version into `Info.plist`.
2. Re-signs the `.app` with the **Developer ID Application** certificate, the entitlements file, and hardened runtime.
3. Builds a compressed DMG containing the `.app` and an `Applications` symlink.
4. Submits the DMG to Apple for notarization.
5. Staples the notarization ticket to the DMG.
6. Validates the result with `spctl --assess --type install`.

The DMG is written next to the `.app` bundle at the git common root, named:

```
AgentSessionManager-<short-version>-<build-number>.dmg
```

For example:

```
AgentSessionManager-0.0.1-197.dmg
```

### Version Stamping

`make dist` derives version numbers from git state:

- `CFBundleShortVersionString` comes from the latest git tag with the leading `v` removed. If no tag exists, it falls back to `0.0.1`.
- `CFBundleVersion` comes from `git rev-list --count HEAD` and is guaranteed to be monotonic.

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

## First-Distribution Verification Checklist

- [ ] `make dist` completes without errors.
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
