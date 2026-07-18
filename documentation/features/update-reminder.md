# Update Reminder

Agent Session Manager checks for newer versions in two mutually exclusive ways, selected at runtime by `DistributionChannel` from `Info.plist`.

## Channels

| Channel | Detection mechanism | Typical build |
|---|---|---|
| `sourceMain` | Compare local `main` commit SHA to `origin/main` via the GitHub API. | `make run`, ad-hoc-signed development builds |
| `dmg` | Sparkle checks `appcast.xml` and prompts to download a new DMG. | `make dist` Developer ID + notarized builds |

The `ASMDistributionChannel` key in `Info.plist` determines which path is active. `scripts/dist.sh` writes `dmg` and strips `ASMSource*` keys; source builds leave the key absent or set to `sourceMain`.

## User Interface

A small update indicator appears in the tab bar when a newer version is available:

- **Source builds:** shows "Update Available" and opens the repository URL in the default browser.
- **DMG builds:** shows "Update Available" and triggers Sparkle's standard update flow (download, install, relaunch).

The same indicator is also surfaced in Settings → About.

## Source Builds

`MainBranchUpdateDetector` runs `git rev-parse origin/main` and `git rev-parse HEAD` in the repository that built the app. If `origin/main` is ahead, it reports an available update. This only works when:

- The build directory is a git checkout.
- `origin/main` is reachable.
- The GitHub API is available (a private repo requires `gh auth`).

## DMG Builds

`DMGReleaseDetector` hosts a Sparkle `SPUUpdater`. It reads `SUFeedURL` and `SUFeedPublicEdKey` from `Info.plist` and checks the public `appcast.xml` at the configured GitHub Pages URL.

Release signing uses EdDSA:

- `scripts/generate-sparkle-keys.sh` creates `sparkle_private.pem` and `sparkle_public.pem` once per release machine.
- `scripts/sign-update.sh` signs the DMG before upload.
- `scripts/update-appcast.sh` appends the signed item to `appcast.xml`.
- `scripts/dist.sh` wires all three into `make dist`.

Do not commit `sparkle_private.pem`.

## Adding a New Channel

To route a new distribution channel through the update system:

1. Add a case to `DistributionChannel`.
2. Add a detector that conforms to `UpdateDetector`.
3. Add the routing branch in `UpdateCheckCoordinator.detectUpdate()`.
4. Provide tests that exercise the new detector and routing.

## Developer Map

| Area | File |
|---|---|
| Channel model | `Sources/AgentSessionManager/Models/DistributionChannel.swift` |
| Detector protocol and state | `Sources/AgentSessionManager/Controllers/UpdateDetector.swift` |
| Source / main detector | `Sources/AgentSessionManager/Controllers/MainBranchUpdateDetector.swift` |
| DMG / Sparkle detector | `Sources/AgentSessionManager/Controllers/DMGReleaseDetector.swift` |
| Channel routing | `Sources/AgentSessionManager/Controllers/UpdateCheckCoordinator.swift` |
| Update UI entry points | `Sources/AgentSessionManager/Views/TabBarView.swift`, `Sources/AgentSessionManager/Views/SettingsView.swift` |
| DMG signing and feed update | `scripts/dist.sh`, `scripts/sparkle-tools.sh`, `scripts/generate-sparkle-keys.sh`, `scripts/sign-update.sh`, `scripts/update-appcast.sh` |
| Public appcast feed | `appcast.xml` |
