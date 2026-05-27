# Settings Navigation

The Settings window uses a **sidebar navigation** layout (Xcode-style) rather than a flat tab toolbar. A `NavigationSplitView` renders the list of sections in a fixed-width left sidebar; the selected section's content fills the resizable detail pane on the right.

## Sections

All nine sections are enumerated in `SettingsSection` (`SettingsView.swift`). Each case carries a `title` string and an SF Symbols `icon` name that match the original tab labels verbatim:

| Case | Title | Icon |
|------|-------|------|
| `.general` | General | `gear` |
| `.profiles` | Profiles | `person.crop.rectangle.stack` |
| `.tools` | Tools | `wrench.and.screwdriver` |
| `.cliOptions` | CLI Options | `terminal` |
| `.worktrees` | Worktrees | `folder.badge.gearshape` |
| `.shortcuts` | Shortcuts | `keyboard` |
| `.statusLine` | Status Line | `chart.bar` |
| `.notifications` | Notifications | `bell` |
| `.tracing` | Tracing | `waveform` |

## Accessibility identifiers

Each sidebar row carries the accessibility identifier `settings-sidebar-<rawValue>`, where `rawValue` is the kebab-case enum raw value (e.g. `settings-sidebar-cli-options`). UI tests use `app.descendants(matching: .any).matching(identifier: "settings-sidebar-<rawValue>").firstMatch` to navigate sections.

## Window resizability

The Settings scene uses `.windowResizability(.contentSize)` so the window can be dragged to any size within the `minWidth: 720 / minHeight: 520` floor set by the `NavigationSplitView` frame.
