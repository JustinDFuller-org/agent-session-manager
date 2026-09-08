# Agent Control MCP QA Findings

Date: 2026-07-24 Build: `agent-session-manager.dev` Branch: `agentic-control`

## Summary

The live MCP server successfully created, focused, inspected, and deleted tabs and panes. Managed worktree cleanup worked. Profile lifecycle mutations and global status-line updates also succeeded and were restored afterward.

The second Codex pane creation was not stuck: `panes.create` returned `succeeded` in 3.6 seconds, the pane transitioned from `idle` to `running` on the first workspace read, and it remained `running` across four additional ten-second polls.

## Confirmed working

- `debug_set_mode` persisted Debug Mode changes and exposed trace capture.
- Workspace, profiles, harnesses, status-line, notifications, diagnostics summary, and diagnostics trace resources were readable at Global scope.
- `tabs.create`, `tabs.focus`, and `tabs.delete` succeeded.
- `panes.create` created a Codex pane with `agentControlInjectionEnabled: true` and a managed worktree.
- `panes.delete` with `cleanup: delete` removed the managed worktree.
- Profile create, update, reorder, and delete all succeeded.
- Global status-line configuration updated, read back correctly, and was restored.
- Mutation traces recorded the live MCP operations with successful results.
- Final workspace state returned to the original one-tab, one-pane setup.
- The dev telemetry collector found no malformed JSONL lines or invariant violations for the tested pane.

## Findings and improvement opportunities

### 1. Diagnostics trace responses need pagination or smaller bounds

The `diagnostics/traces` resource can exceed the MCP/tool response limit. Repeated reads sometimes arrived truncated in the middle of the JSON document, making the resource response invalid JSON. The local telemetry collector could still read the underlying JSONL files, and the diagnostic query reported a bounded result set of 100 records.

Recommended follow-up:

- Add an explicit limit and cursor or `since`/`until` query contract to the MCP resource.
- Keep the default response small enough to remain valid through normal MCP transports.
- Return structured truncation metadata without inserting truncation into a JSON document.

### 2. Invariant availability does not match Debug Mode capture state

Enabling Debug Mode returned `invariantsCapturing: true`, but the diagnostics summary still reported `invariantsReadable: false`. No invariant violations were found during collection, so this may be an empty-resource availability issue rather than a capture failure.

Recommended follow-up:

- Define whether `invariantsReadable` means capture is enabled, a file exists, or the resource has records.
- Expose those states separately, or make an empty invariant resource readable.

### 3. Mutation responses should use one consistent workspace snapshot

One `panes.create` response reported the new `activePaneID` while retaining the previous `activeTabID`. An explicit `tabs.focus` call corrected the active state. This may be an eventual-consistency race, but consumers should not receive contradictory active identifiers in one mutation result.

Recommended follow-up:

- Re-read active tab and pane state before constructing mutation responses.
- Add a regression test for creating a pane in a newly created or non-active tab.

### 4. Scope requirements are not sufficiently discoverable

Global resources were unavailable while Agent Control was scoped to Pane. Changing the setting to Global made the same resources available.

Recommended follow-up:

- Include the required scope in authorization errors.
- Expose current scope and available capabilities from a universally readable resource.
- Consider making diagnostics summary available at every scope.

### 5. Initial prompts are harness-specific

Pane creation accepts `cliOptions`, but the available options depend on the selected harness. OpenCode exposes `--prompt`; the Codex catalog used for the retry pane does not expose `--prompt`.

Recommended follow-up:

- Document that `--prompt` is an initial startup argument, not arbitrary later terminal input.
- Add harness-specific validation for unsupported options.
- If later input is required, expose a bounded `panes.send_input` operation with audit tracing rather than relying on OS-level keystroke injection.

## Separate signal

The dev pane traces contained repeated PR polling records with `exit_code: 127` and empty responses. This did not prevent the MCP operations and appears separate from Agent Control, but it should be investigated independently because it adds error noise to diagnostics.

## QA limitations and remaining coverage

- The screenshot capture selected Chrome instead of the Dev app. System Events reported that the runner lacked Accessibility permission, so no screenshot was counted as visual pass evidence.
- Notification acknowledgement was not exercised because this run did not create a notification.
- Pane restart/reorder and harness enablement or CLI-catalog mutations remain untested.
- Dev UI automation timed out while enabling automation before reaching test assertions.

## Cleanup state

The first disposable tab, pane, profile, and managed worktree were removed. The second retry pane was verified running for the additional polling window and is also absent from the final workspace state.

## Implementation status

The actionable Agent Control follow-ups from this QA pass are implemented:

- Diagnostic resources accept bounded `limit`, `sinceEpochMs`, and `untilEpochMs` query parameters. Resource reads default to 20 records and cap requests at 50.
- Diagnostic readability is separate from durable capture state, including for empty invariant resources.
- Mutation selection state is normalized when deleting the active tab, and pane creation switches to its target tab before selecting the new pane.
- Diagnostic summaries expose the current scope and Global-only capabilities, while authorization errors identify the required and current scope.
- Unavailable harness CLI options are rejected before pane worktree setup.
- Agent Control scope now defaults to Global for new and legacy settings without an explicit scope. Explicitly persisted Pane and Tab scopes remain unchanged.

The repeated PR polling records with `exit_code: 127` remain a separate investigation. The screenshot and Dev UI automation limitations were not treated as visual verification evidence.
