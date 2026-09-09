## Why

The repository currently maintains a custom API-polling aggregator and several independently triggered validations, which makes required status behavior dependent on cross-run discovery, candidate-controlled workflow conditions, and stale provenance rules. Replace that machinery with GitHub Actions' native reusable workflows, job dependencies, outputs, conditions, concurrency, and `always()` aggregation so every pull request has one stable, reviewable gate.

## What Changes

- Replace the base-owned API polling and JSON policy engine with one ordinary `pull_request` CI caller whose final `ci-gate` job is the sole required status context.
- Convert PR validation workflows into local `workflow_call` workflows while preserving their existing push, schedule, and manual entry points where they are useful outside pull-request merge accounting.
- Add a tested Git preflight that compares the stack base SHA with the pull-request head, classifies documentation-only, required, or trusted-disabled macOS validation, and fails closed for unknown or malformed input.
- Make all macOS caller jobs depend on the preflight and every lightweight validation, and make the final gate depend on every caller with `always()`.
- Remove the title-based WIP action and keep OpenSpec guide comments and label application as separate best-effort automation outside the merge gate.
- Delete the custom policy, API adapter, evaluator, polling workflow, integration tests, and guidance tests that are no longer needed.
- Add focused preflight and workflow-contract tests covering applicability, stack-base selection, failure propagation, security boundaries, permissions, action pinning, and intentional skips.
- Rewrite the internal guidance and QA evidence for the native DAG and document the manual ruleset transition to the GitHub Actions `ci-gate` context.
- Migrate the formal stack to the revised proposal, one implementation layer, guidance, QA, and archive, closing replaced implementation pull requests only after the new formal stack is verified.

No application API, Swift type, persistence format, or user-facing application behavior changes. The repository remains private and user-owned; organization-level required workflows and any change to review freshness settings remain out of scope.

## Capabilities

### New Capabilities

- `strict-ci-gate`: Native pull-request validation orchestration, trusted macOS preflight, and one authoritative gate.

### Modified Capabilities

- None.

## Impact

The change affects `.github/workflows/`, `.github/scripts/`, internal CI/OpenSpec guidance, OpenSpec QA evidence, and formal GitHub stack/ruleset configuration. It does not change `Sources/`, application tests, application persistence, or the macOS product runtime.

## Follow-ups after merge

- Keep `ci-gate` as the only required status context after the ruleset migration is verified live on `main`.
- Re-enable the trusted `ENABLE_MACOSX_JOBS` repository variable only through the documented owner-approved procedure when macOS capacity is available.
