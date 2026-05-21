# Tab Loading Indicator

## What It Is

A small green pulsing dot that appears in the tab bar next to a tab's name when any of that tab's panes has a running process.

## When It Appears and Disappears

The dot is visible when at least one pane in the tab has a `.running(pid:)` process state. It disappears as soon as all panes in the tab have exited (`.exited(code:)`) or are idle.

## How It Works

`Tab.hasRunningPane` is a computed property that checks whether any pane's `TerminalController.processState` matches `.running`. Because `Tab` and `TerminalController` are both `@Observable`, SwiftUI automatically re-renders `TabButtonView` when any pane's process state changes — no timers or polling needed.

The dot uses the same animation already present on the per-pane status indicator: `.easeInOut(duration: 1.2).repeatForever(autoreverses: true)`, triggered via `.onAppear`.

## Coexistence with Notification Dot

The loading dot and the notification dot are independent signals. Both can appear simultaneously on the same tab — the loading dot always appears first (to the left of the notification dot).
