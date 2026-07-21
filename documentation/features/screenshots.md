# UI Test Screenshots

The screenshot walkthrough captures the app in one continuous session for documentation and PR review.

## Coverage

ScreenshotTests captures all 27 views in order:

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
- split-panes
- settings-panes
- settings-notifications
- settings-profiles
- settings-tools
- settings-shortcuts
- settings-status-line
- settings-debug
- pane-status-indicators
- activity-indicator-states
- focused-pane
- notification-sidebar
- pr-merged-alert
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

## Temporary PR provider fixture

The PR sidebar and alert are captured through the normal PRTrackingCoordinator, StatusLineMonitor, AppState notification, and alert paths. For repeatable local runs, the screenshot test temporarily places a generated gh executable first on PATH. It handles only gh api graphql --include --input, returns an open PR initially, and returns the same PR as merged after the test changes its fixture state.

This temporary provider fixture avoids opening or merging an external GitHub PR on every run. It does not fabricate sessions, panes, notification arrays, or view state. It can be removed later without changing the screenshot walkthrough or production PR notification code.

## Authenticity

Screenshots are produced through one continuous app session and real UI flows. Panes are created through the New Pane sheet, terminal processes run through the normal TerminalController path, terminal attention uses the existing bell handling, and diagnostics use the app-owned trace, invariant, and status-line inputs.

The temporary GitHub provider fixture is the only intentional fake. It is isolated at the external CLI boundary while the app’s production PR transition and notification behavior remain under test.

## Workflow integration

The workflow skill runs make screenshots during verification. make pr-screenshots captures the same canonical set, uploads the PNGs to a gist, and rewrites the PR Example section in place.
