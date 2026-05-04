# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Agent Session Manager is a native macOS app (Swift/SwiftUI, macOS 14+) for running multiple AI agent sessions in parallel. It provides a tabbed, multi-pane terminal window where each pane runs Claude Code in a git worktree context—typically `claude --worktree <name>` from the repo root for checkouts under `.agent-session-manager/worktrees/`, or `claude` with the process working directory set to an existing worktree elsewhere—letting you work on several tasks simultaneously without context switching between windows.

**Tabs** represent a working directory. Each tab has a name and a root directory. You can have many tabs open at once and switch between them with ⌘1–⌘9.

**Panes** are terminal sessions inside a tab. When you create a pane you give it a session/worktree name; the app launches Claude Code accordingly. Worktrees **created by the app** live only under `<repo>/.agent-session-manager/worktrees/<name>` (similar to Claude’s `.claude/worktrees/`). If a branch is already checked out in any path `git worktree list` knows about, the app can open that checkout (working directory = that path, no `--worktree` flag). Panes auto-arrange in a grid (1×1 → 2×1 → 2×2 → 3×2 → 3×3) as you add more. Each pane shows a live status indicator: green pulsing dot when the process is running, gray when it has exited.

**Status line** — each pane shows a configurable status bar at the bottom. It is populated by Claude Code's `statusLine` hook via a per-pane temp settings file (`--settings /tmp/agent-session-manager-settings-<UUID>.json`) so every concurrent pane has its own isolated data file. All 24 available Claude data fields are exposed in Settings → Status Line (model, cost, context %, worktree, effort, vim mode, rate limits, etc.). Four are on by default: model, worktree name, cost, and context %.

**CLI options** are configurable per-pane. A built-in library of 62 Claude CLI flags can be enabled/disabled in Settings; enabled flags appear as toggles and text fields in the New Pane sheet. Users can also add custom flags. Settings are persisted across launches.

**Session persistence** saves tabs and pane names to `~/Library/Application Support/agent-session-manager/sessions.json`. On relaunch the app restores tabs and restarts `claude` in any pane whose checkout still exists on disk—under `.agent-session-manager/worktrees/<name>`, legacy `.tree/<name>`, or an absolute path stored when the pane reused an external worktree.

**Keyboard shortcuts:**
- ⌘T — new tab
- ⌘⇧N — new pane
- ⌘W — close active pane
- ⌘1–⌘9 — switch to tab by index

## Core Design Principle

The tab/pane workflow is fixed — that structure is the product. What happens *inside* a pane is not. People use Claude in very different ways (different flags, models, personas, workflows), and that diversity is a feature, not a problem to solve. Every design decision should preserve room for that customization within the core workflow rather than hardcoding assumptions about how Claude should be invoked.

Concretely: the core workflow (create tab → create pane → terminal session) should remain simple and opinionated. The configuration surface (CLI flags, custom options, per-pane settings) should remain open and extensible.

## Naming

Do not use the acronym **ASM** for this app in documentation, comments, UI copy, or commit messages—write **Agent Session Manager** in full. Avoid new temp-file basenames or code identifiers that use `asm-` as shorthand for the product; prefer explicit prefixes such as `agent-session-manager-…`.

## Terminal Purity

The terminal pane is Claude's UI, not a setup script runner. Users should never see app-level plumbing (git commands, setup output, error text from the app) in the terminal. Any setup the app needs to do before launching Claude — creating worktrees, fetching branches, writing config files — must happen in Swift using `Foundation.Process` or file APIs, not by prepending shell commands to the Claude invocation.

Concretely: `buildClaudeCommand()` and similar functions must only emit the final tool invocation (`claude ...`, `codex ...`). All prerequisite work runs in the app layer (e.g. `Tab.resolveOrAttachWorktree()` when attaching to an existing branch/worktree) and surfaces errors through SwiftUI UI (sheets, inline error text), not through the terminal.

## Build & Run Commands

```bash
make build        # swift build -c release
make app          # build + bundle into .app
make run          # build, bundle, and open the app
make restart      # kill and reopen the running app without rebuilding
make watch        # watch Sources/ and Tests/ for changes, auto rebuild+restart (no external tools needed)
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

**IMPORTANT**: Update the test suite with every change. Unit tests live in `Tests/` (e.g. `CLIOptionConfigTests.swift`, `WorktreeListParserTests.swift`). UI tests live in `UITests/`. The app passes `--uitesting-skip-restore` during UI test runs to bypass session restoration.

## Architecture

**Entry point:** `Sources/AgentSessionManager/App.swift` — initializes `AppState` and `AppSettings`, restores persisted state, registers ⌘T shortcut.

**Models** (`Models/`):
- `AppState` — `@Observable` root state; owns the list of tabs and tracks active tab/pane IDs
- `Tab` — A directory context containing one or more `Pane`s; responsible for spawning Claude processes and (when needed) resolving or creating git worktrees—new trees only under `.agent-session-manager/worktrees/`, existing checkouts anywhere listed by `git worktree list`
- `Pane` — One terminal session; holds a `TerminalController`
- `AppSettings` — In-memory state for which CLI flags are enabled and status line configuration
- `CLIOptionConfig` — Defines 62 predefined Claude CLI flags plus user-added custom flags; handles flag type mapping (boolean vs. string) and JSON persistence
- `StatusLineConfig` — Defines 24 status line items (visibility, labels); `StatusLineData` decodes the JSON Claude passes to the statusLine hook command
- `GridLayout` — Computes pane grid dimensions (1×1 → 2×1 → 2×2 → 3×2 → 3×3) based on pane count

**Controllers** (`Controllers/`):
- `TerminalController` — Wraps SwiftTerm's `LocalProcessTerminalView`; tracks process state (idle/running/exited) via `LocalProcessTerminalViewDelegate`
- `SessionPersistence` — Saves/restores tabs, panes, and active tab to `~/Library/Application Support/agent-session-manager/sessions.json`
- `SettingsPersistence` — Saves/restores enabled CLI flags to `settings.json` and status line config to `statusline-settings.json`
- `StatusLineMonitor` — Per-pane `@Observable` class; writes a temp settings file that configures Claude's `statusLine` hook to pipe JSON into a temp status file, then watches that file with `DispatchSourceFileSystemObject` and exposes parsed `StatusLineData`

**Views** (`Views/`):
- `ContentView` — Root; composes `TabBarView` + `PaneGridView`; owns NSEvent keyboard monitor for ⌘W and ⌘1–9
- `TerminalRepresentable` — `NSViewRepresentable` wrapping SwiftTerm; defers process start until the view frame is non-zero (layout must be complete before the terminal resizes correctly)
- `NewPaneSheet` — CLI picker, optional “Existing branch or worktree” flow for Claude, and dynamic CLI option toggles from `CLIOptionConfig`
- `SettingsView` — Three-tab settings window: CLI Options (flag visibility), Shortcuts (key bindings), Status Line (item visibility)
- `StatusLineView` — Renders visible status items as a monospaced caption bar; formats durations, reset times, cost, token counts, and all other Claude data fields

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

## Documentation

- **Feature guides** — `documentation/features/` (e.g. `worktree-creation.md` for git worktree paths and New Pane modes).

## Key Behaviors to Know

- Processes are started lazily inside `TerminalRepresentable` once the frame is laid out — don't move process start earlier.
- Session persistence triggers on tab count or active-tab changes; settings persistence triggers on settings changes.
- The app is sandboxed except for automation entitlements (`AgentSessionManager.entitlements`).
- `URL(string:)` is used in session restore — known issue with paths containing spaces; prefer `URL(filePath:)` in new code.
