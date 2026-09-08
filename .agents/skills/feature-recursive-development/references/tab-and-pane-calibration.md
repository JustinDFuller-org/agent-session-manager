# Tab-and-pane calibration

Use this sample Computer Use scenario after a focused build or test when a small visual acceptance check is useful. It checks the owned Dev launch, the normal New Tab flow, and—only when an explicitly supplied disposable checkout is available—the normal New Pane flow. It is a template, not a generic test runner.

## Inputs and prerequisites

- A fresh run started with `scripts/recursive-development.sh start`.
- The run ID from `start`, plus its verified branch, commit, bundle, PID, and title from `status`.
- Codex Computer Use installed, in a new session, with Screen Recording and Accessibility granted.
- Optional `tab_name`, `pane_name`, and an existing disposable `worktree_name`. Do not create a new worktree merely to make this scenario pass. If no disposable checkout is supplied, stop after tab creation and mark pane-dependent evidence as skipped.

## Steps

1. Inspect the fresh `AgentSessionManagerDev` accessibility state. If first launch onboarding appears, dismiss it through its visible Skip control and inspect again.
2. Verify the exact title `Agent Session Manager (Dev · <run-prefix>)` and cross-check the manifest through `status`. If either identity check fails, stop and preserve the run for diagnosis.
3. Use the visible New Tab flow: invoke the shortcut or control, set a descriptive tab name, choose the intended repository directory in the system picker, and create the tab. Inspect state before each action.
4. Save a target-window screenshot returned by Computer Use under `.build/recursive-development/<UUID>/screenshots/`. Inspect it first; do not save a screenshot containing terminal secrets.
5. When trace evidence is needed, open Settings through the app UI, select Debug, enable Debug Mode, verify the visible toggle, and return to the owned main window.
6. If `worktree_name` was supplied, use the real New Pane flow to attach that existing disposable checkout. Do not type a prompt into the terminal. Inspect the resulting pane's visible name and status, then save a second safe screenshot.
7. Run `collect --run-id <UUID> --tab <tab_name> --pane <pane_name>` only after a pane exists. Confirm selected-pane traces, malformed JSONL, and matching invariant results independently. Without a pane, collect without selectors and report telemetry as unverified rather than inferred.
8. Run the focused Dev XCTest for the changed behavior separately and retain its `.xcresult`. Its result never substitutes for the screenshot.
9. Run `stop --run-id <UUID>`. Confirm that the verified owned PID exited and the UUID support directory was removed. Do not remove a worktree, kill a broad process name, or change ordinary Dev/production state as part of this scenario.

## Result classification

- **Visual passed** requires the exact title and at least one safe Computer Use screenshot of the real result.
- **Functional passed** requires the visible tab result, and pane result only when the supplied scenario requires a pane.
- **Telemetry/invariants passed** require selected, parseable evidence; an empty or unavailable collector is unverified.
- **Automated tests** report XCTest independently. Automation startup failure is unverified, not an application assertion failure.
- **Cleanup passed** requires the owned PID exit and UUID-scoped support removal. A user-owned worktree remains outside run cleanup.
