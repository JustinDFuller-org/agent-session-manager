# UI Test Screenshots

The screenshot walkthrough captures the app in one continuous session for documentation and PR review.

## Coverage

ScreenshotTests captures all 31 views:

- onboarding-welcome
- onboarding-shell
- onboarding-tools
- onboarding-status-line
- onboarding-cli-flags
- onboarding-profiles
- empty-state
- new-tab-sheet
- new-tab-sheet-filled
- main-window-tab
- new-pane-sheet
- new-pane-agent-control
- split-panes
- pane-scrollback-menu
- existing-worktree-prompt
- worktree-cleanup-alert
- reordered-tabs-and-panes
- settings-panes
- settings-agent-control
- settings-notifications
- settings-profiles
- settings-tools
- settings-shortcuts
- settings-status-line
- settings-debug
- pane-status-indicators
- notification-sidebar
- focused-pane
- trace-dashboard
- trace-waterfall
- invariant-dashboard

The app launches once and terminates once. Each screenshot is captured after the preceding real UI flow has completed, so later images show the same session continuing through the product.

BaseTestCase.screenshot() writes PNG files only when SCREENSHOTS_OUTPUT_PATH is set. Normal make test-ui-dev runs retain screenshots as XCTest attachments; make screenshots additionally writes them to screenshots/ in the repository root.

For the macOS 26 visual baseline, the walkthrough prepares the default branch fixture as main before launch so the New Tab sheet uses the canonical branch.

## Generating screenshots

    make screenshots

This runs only ScreenshotTests and writes PNGs to screenshots/. The directory is gitignored; the workflow force-adds it when creating a PR.

## Multi-worktree safety

The Makefile passes the absolute worktree screenshots directory through TEST_RUNNER_SCREENSHOTS_OUTPUT_PATH. xcodebuild strips the TEST_RUNNER_ prefix before forwarding the variable to the test process, so simultaneous worktrees write to separate directories.

## Authenticity

Screenshots are produced through one continuous app session and real UI flows. Panes are created through the New Pane sheet, worktree prompts use real Git worktrees, reordering uses real drag gestures, and terminal attention uses the existing bell handling. The walkthrough does not inject sessions, panes, notification arrays, activity states, or GitHub pull-request data.

## Workflow integration

The workflow skill runs make screenshots during verification. make pr-screenshots captures the same canonical set, uploads the PNGs to a gist, and rewrites the PR Example section in place.
