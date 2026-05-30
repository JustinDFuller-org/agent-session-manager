# Tab & Pane Activity Indicators

Every tab and pane shows a small indicator that answers one question: **where should I focus attention right now?**

## Three states (priority order)

| State | Visual | Meaning |
|-------|--------|---------|
| **Waiting** | Filled accent-color dot, breathing pulse | Agent needs your input — a notification is pending |
| **Working** | Rotating monochrome arc | Agent is actively producing output or is in a busy/retry session state |
| **Idle** | Static dim hollow ring | Process stopped or running quietly with no output |

A tab aggregates its panes: it shows `waiting` if any pane is waiting, `working` if any pane is working, and `idle` otherwise. Every tab always shows an indicator so an idle tab is positively identifiable, not just "absent dot."

## Working detection

A pane is `working` when:
- `processState == .running`, **and**
- The terminal produced PTY output within the last ~700 ms (`isProducingOutput == true`), **or**
- The session status state is `busy` or `retry`

Output detection is implemented by overriding `BellCapturingTerminalView.dataReceived(slice:)` which is called on every PTY read. A debounce timer (700 ms) resets `TerminalController.isProducingOutput` after output stops.

## Waiting and notifications

A pane is `waiting` whenever `AppState.notifications` contains an entry for that pane — regardless of notification kind (`terminalBell` or `prMerged`). Focusing the pane clears its notification (`AppState.setActivePane` → `clearNotification`), reverting the indicator to `working` or `idle`. The active pane therefore never shows `waiting`.

This means the activity indicator and the notification are the same signal. There is no separate notification dot in the pane header.

## PR status is separate

PR status (CI checks, merge state) appears only in the status-line `pr` fact and its popover. The activity indicator has no knowledge of PR state. This prevents the indicator from turning red/purple on CI failure or merge — those are informational, not attention-requiring.

## Reduce Motion

When Accessibility → Reduce Motion is enabled:
- **Working**: shows a static monochrome filled dot (no rotation)
- **Waiting**: shows a static accent-color dot (no pulse)
- **Idle**: unchanged (already static)

All three states remain visually distinguishable without animation.

## Accessibility identifiers

Format: `{prefix}-activity-{state}-{name}`

Examples:
- `pane-activity-idle-feature-a`
- `pane-activity-working-feature-a`
- `pane-activity-waiting-feature-a`
- `tab-activity-idle-WorkTab`
- `tab-activity-waiting-WorkTab`

## Enable / disable

Settings → Panes → **Show Activity Indicators** toggle (`settings-activity-indicators-toggle`).

When off, `ActivityIndicatorView` renders nothing. The setting is persisted to `activity-indicator-settings.json`.

## Tracing events

| Event | When |
|-------|------|
| `pane.activity.output_started` | `isProducingOutput` flips false → true (rising edge only) |
| `pane.activity.output_stopped` | debounce fires, `isProducingOutput` flips true → false |
| `pane.notification.cleared` | `clearNotification(paneID:)` called with `reason: "cleared"` |

The `pane.notification.added` event was already traced; `cleared` was added to make enter/exit symmetric and debuggable.
