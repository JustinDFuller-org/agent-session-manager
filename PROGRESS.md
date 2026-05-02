# Progress

## Initial Build — Complete

Built a native macOS session manager (Swift/SwiftUI + SwiftTerm) from scratch.
All 7 planned stages completed and committed.

### What works

**Tabs**
- Create a tab with a name and a directory (`⌘T` → sheet → NSOpenPanel)
- Switch between tabs; tab bar shows name + directory's last path component
- Close a tab (closes all its panes and their processes)
- Active tab highlighted with accent border

**Panes**
- Create a pane inside the active tab (`⌘⇧N` → sheet → worktree name)
- Pane auto-launches `claude --worktree <name>` in the tab's directory
- Panes auto-arrange in a grid: 1×1 → 2×1 → 2×2 → 3×2 → 3×3
- Close a pane (`⌘W` for active pane, or click the × in the pane header)
- Active pane tracked by mouse-click; highlighted with accent-colored border
- Green pulsing status dot when process is running; gray on exit

**Keyboard**
- `⌘T` — new tab
- `⌘⇧N` — new pane
- `⌘W` — close active pane
- `⌘1`–`⌘9` — switch to tab by index

**Session persistence**
- Tabs and pane names saved to `~/Library/Application Support/agent-session-manager/sessions.json`
- On relaunch: restores tabs, restarts claude in panes whose worktrees still exist on disk

### Build

```
make run      # build + assemble .app + open
make build    # swift build -c release only
make clean    # remove .build/ and .app/
```

No Xcode required. Single external dependency: SwiftTerm 1.13.0.

---

## Known issues / next iteration candidates

- `processState` in `TerminalController` never transitions to `.running(pid:)` — SwiftTerm's `LocalProcessTerminalView` doesn't expose the PID via a delegate callback. Needs investigation to get live PID for SIGTERM on close.
- `⌘T` keyboard shortcut fires via `NotificationCenter` from the SwiftUI `Commands` group — need to verify it reaches `ContentView.onReceive` in all focus states.
- Session restore uses `URL(string: "file://\(path)")` which may mishandle paths containing spaces; should use `URL(filePath:)`.
- No confirmation dialog when closing a tab with active panes.
- Pane grid doesn't animate reflows (panes just snap into new positions).
- No way to rename a tab or pane after creation.
