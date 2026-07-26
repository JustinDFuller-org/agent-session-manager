# PR Merged Notifications

When a pane's GitHub PR tracking detects that a pull request has been merged, Agent Session Manager shows a notification so you can act on the pane immediately.

## What happens

When the PR tracking poll (every 60 seconds) observes a transition from a non-merged state to `"merged"`:

1. A **sidebar notification** appears with a purple merge icon (↗), the `tab / pane` label, and a compact "PR #N merged" reason.
2. A **macOS desktop banner** appears with the title "PR Merged", `tab / pane` as subtitle, and `PR #N merged: title` in the body.
3. Clicking either notification opens an **action prompt** with three choices.

The notification fires only once per pane per session — on a live open→merged transition. Panes that are already merged when the app launches do not produce a notification (to avoid false positives on restart).

A PR-merged row replaces any regular unread attention row for the same pane. Lower-priority attention signals are ignored until the PR row is cleared.

## Action prompt

When you click a PR merged notification (sidebar row or banner), a "PR Merged" alert appears:

| Button | Effect |
|--------|--------|
| **Close Pane** | Closes the terminal pane without touching the worktree on disk. |
| **Close Pane and Clean Up Worktree** | Removes the git worktree (`git worktree remove`) and closes the pane. Only available for managed worktrees. |
| **Cancel** | Focuses the pane, clears the notification dot, and dismisses the alert. |

## Configuration

Toggle PR merged notifications in **Settings → Notifications → GitHub PR → PR Merged Notifications**.

When disabled, no sidebar entry or macOS banner is shown for merged PRs. The PR status in the status line still updates normally.

This setting is stored in `~/Library/Application Support/agent-session-manager/notification-settings.json` and defaults to **on**.

## Requirements

- GitHub CLI (`gh`) installed and authenticated (same requirement as the PR tracking feature).
- PR tracking enabled in **Settings → Status Line** or **Settings → General**.
- macOS banner notifications require permission in **System Settings → Notifications**.

## Related features

- [PR Tracking]({{ '/documentation/features/pr-tracking/' | relative_url }}) — how PR state is polled and displayed in the status line.
- [Notifications]({{ '/documentation/features/notifications/' | relative_url }}) — sidebar and banner notification system.
- [Worktree Cleanup]({{ '/documentation/features/worktree-cleanup/' | relative_url }}) — how worktrees are removed when closing panes.
