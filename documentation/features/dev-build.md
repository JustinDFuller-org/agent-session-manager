# Dev Build

## What It Is

Agent Session Manager supports separate production and development builds so you can dogfood the app while safely developing it. The dev build uses a different bundle identifier (`com.justinfuller.agent-session-manager.dev`) which automatically isolates all persisted data into a separate directory.

## How It Works

The persistence directory is derived from the last component of the app's bundle identifier:

| Build | Bundle ID | Application Support Directory |
|---|---|---|
| Production | `com.justinfuller.agent-session-manager` | `~/Library/Application Support/agent-session-manager/` |
| Dev | `com.justinfuller.agent-session-manager.dev` | `~/Library/Application Support/agent-session-manager.dev/` |

This means:
- Dev and prod builds can run simultaneously
- Sessions, settings, and all other state are fully isolated
- No risk of dev work corrupting production data
- The dev window displays "Agent Session Manager (Dev)" in the title bar

## Build Commands

| Command | Purpose |
|---|---|
| `make run-prd` | Build and launch production build |
| `make run-dev` | Build and launch dev build |
| `make watch-prd` | Auto-rebuild and restart production on file changes |
| `make watch-dev` | Auto-rebuild and restart dev on file changes |
| `make build-prd` | Compile production build only |
| `make build-dev` | Compile dev build only |
| `make restart` | Kill and reopen the production app |
| `make restart-dev` | Kill and reopen the dev app |

Legacy shortcuts (`make build`, `make run`, `make watch`) still work as production aliases.

## Toolchain and Dependency Maintenance

The repository uses Swift tools 6.1, Swift 6 language mode, and macOS 14 as its deployment floor. Swift 6.1 or newer and Xcode 16 or newer are required for local builds. The currently validated local toolchain is Swift 6.4 with Xcode 27.0.

Run `make check-toolchain` before diagnosing a build failure. It prints the active Swift and Xcode versions and fails when they are below the supported floor.

Swift package lower bounds live in `Package.swift`, while `Package.resolved` locks the exact dependency graph used by builds. Dependabot checks Swift packages and GitHub Actions daily, groups compatible updates, and keeps major updates review-required. The Dependency and Toolchain Compatibility workflow runs for package or toolchain changes and weekly; it resolves the graph and builds the release package. Unit tests remain covered by the existing test workflows when enabled, avoiding false failures from XCTest SDK isolation differences at the support floor.

When a toolchain or dependency update is accepted, regenerate the Xcode project with `make xcodeproj`, run the complete Dev validation suite, and update the recorded validated versions if the support policy changes.

Packaged apps always stage into the shared git common root, even when the command runs inside a worktree:

| Build | Canonical bundle |
|---|---|
| Production | `<git-common-root>/AgentSessionManager.app` |
| Dev | `<git-common-root>/AgentSessionManagerDev.app` |

Run `make repair-launch-services` to unregister stale prod/dev URLs, register canonical bundles that exist, and verify Launch Services resolves each packaged bundle ID to the canonical URL. `make app` and `make app-dev` run this repair automatically.

## Xcode

The project includes three build configurations. Their products use `.xcode-*` bundle identifiers so DerivedData apps cannot impersonate either packaged app:
- **Debug** — `com.justinfuller.agent-session-manager.xcode-debug`
- **Release** — `com.justinfuller.agent-session-manager.xcode-release`
- **Dev** — `com.justinfuller.agent-session-manager.xcode-dev` with the `DEV_BUILD` compilation condition

Use the `Dev` configuration in Xcode to build the dev variant.

## UI Test Safety

UITests must run against the Dev configuration, never production. The approved default command is `make test-ui-dev`. If you need a focused `xcodebuild test` invocation, it must still pass `-configuration Dev` so `DEV_BUILD` is compiled in and `UITestAppSupport.directory` resolves to `~/Library/Application Support/agent-session-manager.dev/`.

Treat any of these as a blocking misconfiguration and stop before running the suite:
- The command omits `-configuration Dev`.
- The resolved bundle identifier is `com.justinfuller.agent-session-manager` or `com.justinfuller.agent-session-manager.xcode-release`.
- The test run would read or write `~/Library/Application Support/agent-session-manager/`.

If a dev UITest run is interrupted before teardown, clean up with `make reset-app-state-dev` before the next run.
