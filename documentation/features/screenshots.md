# UI Test Screenshots

PR descriptions include inline screenshots of major views so reviewers can see what the UI looks like without running the app themselves.

## How it works

`ScreenshotTests` captures 6 main views and `ScreenshotInjectedTests` captures 3 injected views; together they also walk all 7 Settings pages:

| Screenshot | What it shows |
|---|---|
| `empty-state` | App launched with no tabs |
| `main-window-tab` | Main window with one tab open |
| `new-pane-sheet` | New Pane sheet overlay |
| `split-panes` | Tab with two panes side by side |
| `pane-status-indicators` | Pane header with status badge and empty-state chip row (em-dash placeholders) |
| `notification-sidebar` | Notification sidebar open |
| `pr-merged-alert` | PR merged alert overlay |
| `settings-panes` | Settings → Panes |
| `settings-profiles` | Settings → Profiles |
| `settings-tools` | Settings → CLI Tools |
| `settings-shortcuts` | Settings → Shortcuts |
| `settings-status-line` | Settings → Status Line |
| `settings-notifications` | Settings → Notifications |
| `settings-tracing` | Settings → Tracing |

`BaseTestCase.screenshot()` writes PNG files to disk only when the `SCREENSHOTS_OUTPUT_PATH` environment variable is set. Normal `make test-ui-dev` runs capture screenshots as XCTest attachments (unchanged behavior); `make screenshots` additionally writes them as files.

## Generating screenshots

```bash
make screenshots
```

This runs both `ScreenshotTests` and `ScreenshotInjectedTests` and writes PNGs to `screenshots/` in the repo root. The directory is gitignored; the workflow force-adds it before creating a PR.

## Multi-worktree safety

The Makefile passes `$(CURDIR)/screenshots` via `TEST_RUNNER_SCREENSHOTS_OUTPUT_PATH`. xcodebuild strips the `TEST_RUNNER_` prefix before forwarding the variable to the test process, so the test receives `SCREENSHOTS_OUTPUT_PATH`. Because `$(CURDIR)` is the absolute worktree path, two simultaneous worktrees write to separate directories and cannot race.

## Workflow integration

The [workflow skill](../../.agents/skills/workflow/SKILL.md) runs `make screenshots` as part of step 4 (Verify) and `make pr-screenshots` as the last step 4 action. Screenshots are uploaded to a gist and embedded under the `## Example` section of the PR body — not posted as a separate comment.

Run `make pr-screenshots` after the PR is open to capture fresh screenshots, upload them, and update the `## Example` section in the PR body in place.
