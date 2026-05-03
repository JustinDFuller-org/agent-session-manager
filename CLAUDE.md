# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Agent Session Manager is a native macOS app (Swift/SwiftUI, macOS 14+) for running multiple AI agent sessions in parallel. It provides a tabbed, multi-pane terminal window where each pane runs `claude --worktree <name>` in an isolated git worktree, letting you work on several tasks simultaneously without context switching between windows.

**Tabs** represent a working directory. Each tab has a name and a root directory. You can have many tabs open at once and switch between them with ⌘1–⌘9.

**Panes** are terminal sessions inside a tab. When you create a pane you give it a worktree name; the app immediately launches `claude --worktree <name>` in the tab's directory. Panes auto-arrange in a grid (1×1 → 2×1 → 2×2 → 3×2 → 3×3) as you add more. Each pane shows a live status indicator: green pulsing dot when the process is running, gray when it has exited.

**CLI options** are configurable per-pane. A built-in library of 62 Claude CLI flags can be enabled/disabled in Settings; enabled flags appear as toggles and text fields in the New Pane sheet. Users can also add custom flags. Settings are persisted across launches.

**Session persistence** saves tabs and pane names to `~/Library/Application Support/agent-session-manager/sessions.json`. On relaunch the app restores tabs and restarts `claude` in any pane whose worktree still exists on disk.

**Keyboard shortcuts:**
- ⌘T — new tab
- ⌘⇧N — new pane
- ⌘W — close active pane
- ⌘1–⌘9 — switch to tab by index

## Build & Run Commands

```bash
make build        # swift build -c release
make app          # build + bundle into .app
make run          # build, bundle, and open the app
make xcodeproj    # regenerate Xcode project via xcodegen (required before UI tests)
make clean        # remove .build/, .app/, .xcodeproj/
```

## Testing

**Unit tests** (fast, no Xcode needed):
```bash
swift test
swift test --filter CLIOptionConfigTests/testSpecificTest  # run a single test
```

**UI tests** (requires Xcode + xcodegen):
```bash
make xcodeproj    # regenerate if project.yml changed
make test-ui      # xcodebuild test with UITests scheme
make open-results # open .xcresult bundle to inspect failures
```

**IMPORTANT**: Update the test suite with every change. Unit tests live in `Tests/CLIOptionConfigTests.swift`. UI tests live in `UITests/`. The app passes `--uitesting-skip-restore` during UI test runs to bypass session restoration.

## Architecture

**Entry point:** `Sources/AgentSessionManager/App.swift` — initializes `AppState` and `AppSettings`, restores persisted state, registers ⌘T shortcut.

**Models** (`Models/`):
- `AppState` — `@Observable` root state; owns the list of tabs and tracks active tab/pane IDs
- `Tab` — A directory context containing one or more `Pane`s; responsible for spawning `claude --worktree <name>` processes
- `Pane` — One terminal session; holds a `TerminalController`
- `AppSettings` — In-memory state for which CLI flags are enabled
- `CLIOptionConfig` — Defines 62 predefined Claude CLI flags plus user-added custom flags; handles flag type mapping (boolean vs. string) and JSON persistence
- `GridLayout` — Computes pane grid dimensions (1×1 → 2×1 → 2×2 → 3×2 → 3×3) based on pane count

**Controllers** (`Controllers/`):
- `TerminalController` — Wraps SwiftTerm's `LocalProcessTerminalView`; tracks process state (idle/running/exited) via `LocalProcessTerminalViewDelegate`
- `SessionPersistence` — Saves/restores tabs, panes, and active tab to `~/Library/Application Support/agent-session-manager/sessions.json`
- `SettingsPersistence` — Saves/restores enabled CLI flags and user-added flags to a parallel settings.json

**Views** (`Views/`):
- `ContentView` — Root; composes `TabBarView` + `PaneGridView`; owns NSEvent keyboard monitor for ⌘W and ⌘1–9
- `TerminalRepresentable` — `NSViewRepresentable` wrapping SwiftTerm; defers process start until the view frame is non-zero (layout must be complete before the terminal resizes correctly)
- `NewPaneSheet` — Dynamically renders CLI option toggles/fields from `CLIOptionConfig`
- `SettingsView` — Manages the enabled/disabled state of official flags and user-added custom flags

## Visual Design System

The app uses a **macOS-native, system-integrated** design with no custom color palette or design token file. All styling is inline; follow these implicit patterns to stay consistent.

**Colors — use system semantics only:**
- Backgrounds: `.controlBackgroundColor`, `.windowBackgroundColor` (headers), `.textBackgroundColor` (pane body)
- Text: `.primary`, `.secondary`, `.tertiary`, `.quaternary` — never hardcoded colors for text
- Status: `.green` (running), `.gray.opacity(0.4)` (exited), `.red` (destructive actions only)
- Interactive: `.accentColor` for buttons/active borders; `accentColor.opacity(0.15/0.4/0.6)` for tints

**Active/selected state:** dual signal — background tint (`accentColor.opacity(0.15)`) + stroke border (`accentColor.opacity(0.4–0.6)`). Inactive borders use `opacity(0.1)`.

**Typography:**
- `.headline` — sheet titles, section headers
- `.subheadline` — form field labels
- `.caption` — footer/description text
- Monospaced (`design: .monospaced`) for all technical content: flag names, paths, pane names
- Active tab: `size: 12, weight: .semibold`; inactive: `size: 12, weight: .regular`
- Pane header name: `size: 11, weight: .semibold, design: .monospaced`

**Spacing — multiples of 4:**
- Grid/tight gaps: `4px`
- Form field gaps: `8px`
- Header padding: `10px` horizontal, `5px` vertical
- Sheet content spacing: `20px`
- Sheet outer padding: `24px`

**Corner radii:** `4px` badges, `6px` tab highlights, `8px` pane containers

**Fixed dimensions:** sheets 420px wide (320px for small dialogs), settings window 560×580, tab bar 44px tall, status dot 7×7px, add-pane button 36×36px circle

**Animation:** one animation in the entire app — the running status dot pulses opacity 1.0→0.5 with `.easeInOut(duration: 1.2).repeatForever(autoreverses: true)`. Don't add animations elsewhere without strong justification.

**Empty states:** large icon (`size: 36`) in `.quaternary`, centered, with `.secondary` descriptive text below.

## Project & Issues

- GitHub repo: https://github.com/JustinDFuller/agent-session-manager
- Tasks and bugs are tracked as GitHub Issues: https://github.com/JustinDFuller/agent-session-manager/issues
- Reference the relevant issue number in commit messages and PR descriptions.

## Key Behaviors to Know

- Processes are started lazily inside `TerminalRepresentable` once the frame is laid out — don't move process start earlier.
- Session persistence triggers on tab count or active-tab changes; settings persistence triggers on settings changes.
- The app is sandboxed except for automation entitlements (`AgentSessionManager.entitlements`).
- `URL(string:)` is used in session restore — known issue with paths containing spaces; prefer `URL(filePath:)` in new code.
