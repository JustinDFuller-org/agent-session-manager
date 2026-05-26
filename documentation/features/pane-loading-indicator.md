# Pane Loading Indicator

When creating a pane against a large repo or slow network, git operations (`git fetch` + `git worktree add`) can take 30+ seconds. This feature dismisses the New Pane sheet immediately and shows the pane in the grid with a loading overlay while git work completes in the background.

## Behavior

### Loading overlay

Once the user clicks **Create Pane**, the sheet closes and the new pane appears immediately in the grid with a spinner and "Setting up workspace…" message. Git operations (`resolveOrAttachWorktree`) run in a background task.

When setup completes successfully the overlay disappears and the terminal starts.

### Error overlay

If git operations fail (network error, bad ref, branch not found, etc.) the loading overlay is replaced with an error message and a **Remove Pane** button. The pane can then be dismissed without navigating back to any sheet.

### External takeover dialog

When the resolved worktree is an external takeover and the **Existing Worktree Management** setting is **Ask**, the app shows an `NSAlert` (since the sheet is already dismissed) with the same Manage / Don't Manage / Cancel options as before. Choosing **Cancel** transitions the pane to the error state.

## No configuration required

This behavior is always active. There are no settings to toggle.

## Implementation

Key types and methods:

| Symbol | File | Role |
|--------|------|------|
| `PaneSetupState` | `Models/Pane.swift` | `.loading` / `.failed(error:)` enum |
| `Pane.setupState` | `Models/Pane.swift` | Optional state driving overlay display |
| `Tab.addPaneWithLoadingState(...)` | `Models/Tab.swift` | Creates pane with `.loading` state, no terminal |
| `Tab.completeSetup(for:resolved:managed:...)` | `Models/Tab.swift` | Wires terminal and clears loading state |
| `paneLoadingView` | `Views/PaneView.swift` | Spinner overlay |
| `paneSetupErrorView(error:)` | `Views/PaneView.swift` | Error overlay with Remove button |
