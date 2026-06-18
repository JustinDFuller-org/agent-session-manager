# Settings Navigation

The Settings window uses a fixed `HStack` layout rather than `NavigationSplitView` so the sidebar shell, selected-row styling, and window sizing stay visually stable across SDK changes. The left column is a 200-point custom sidebar with an inset rounded border; the selected section's content fills the fixed-size detail pane on the right.

## Sections

All seven sections are enumerated in `SettingsSection` (`SettingsView.swift`). Each case carries a `title` string and an SF Symbols `icon` name:

| Case | Title | Icon |
|------|-------|------|
| `.panes` | Panes | `square.split.2x1` |
| `.profiles` | Profiles | `person.crop.rectangle.stack` |
| `.tools` | CLI Tools | `wrench.and.screwdriver` |
| `.shortcuts` | Shortcuts | `keyboard` |
| `.statusLine` | Status Line | `chart.bar` |
| `.notifications` | Notifications | `bell` |
| `.debug` | Debug | `ladybug` |

## Accessibility identifiers

Each sidebar row carries the accessibility identifier `settings-sidebar-<rawValue>`, where `rawValue` is the kebab-case enum raw value (e.g. `settings-sidebar-tools`). UI tests use `app.descendants(matching: .any).matching(identifier: "settings-sidebar-<rawValue>").firstMatch` to navigate sections.

## Window shell

The Settings window is a separate auxiliary macOS window titled `AgentSessionManager Settings`. Its content size is pinned to `900×552`, the style mask is limited to titled + closable so the minimize and zoom buttons render disabled, and the standard close button plus `⌘W` dismiss it without affecting the main pane grid.
