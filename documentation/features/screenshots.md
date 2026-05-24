# UI Test Screenshots

PR descriptions include inline screenshots of major views so reviewers can see what the UI looks like without running the app themselves.

## How it works

A dedicated `ScreenshotTests` UI test class captures 6 views:

| Screenshot | What it shows |
|---|---|
| `empty-state` | App launched with no tabs |
| `main-window-tab` | Main window with one tab open |
| `new-pane-sheet` | New Pane sheet overlay |
| `split-panes` | Tab with two panes side by side |
| `settings-general` | Settings → General tab |
| `settings-notifications` | Settings → Notifications tab |

`BaseTestCase.screenshot()` writes PNG files to disk only when the `SCREENSHOTS_OUTPUT_PATH` environment variable is set. Normal `make test-ui` runs capture screenshots as XCTest attachments (unchanged behavior); `make screenshots` additionally writes them as files.

## Generating screenshots

```bash
make screenshots
```

This runs only `ScreenshotTests` and writes PNGs to `screenshots/` in the repo root. The directory is gitignored; the workflow force-adds it before creating a PR.

## Multi-worktree safety

The Makefile passes `$(CURDIR)/screenshots` via `TEST_RUNNER_SCREENSHOTS_OUTPUT_PATH`. xcodebuild strips the `TEST_RUNNER_` prefix before forwarding the variable to the test process, so the test receives `SCREENSHOTS_OUTPUT_PATH`. Because `$(CURDIR)` is the absolute worktree path, two simultaneous worktrees write to separate directories and cannot race.

## Workflow integration

The [workflow skill](../../.agents/skills/workflow/SKILL.md) runs `make screenshots` as part of step 4 (Verify) and force-adds `screenshots/` before creating the PR in step 5. GitHub renders relative-path image references inline when the files exist in the branch.
