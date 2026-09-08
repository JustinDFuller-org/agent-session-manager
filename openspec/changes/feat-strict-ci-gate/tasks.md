## 1. Trusted policy and evaluator contract

- [ ] 1.1 Define the base-owned validation policy with canonical workflow/job identities, trigger expectations, changed-file applicability categories, prerequisite relationships, and the `ENABLE_MACOSX_JOBS` opt-out behavior; verify the policy covers every current pull-request workflow and excludes release, schedule, manual-only, and Dependabot automation.
- [ ] 1.2 Implement pure gate-evaluation logic for applicability, exact-head matching, expected GitHub Actions provenance, and terminal result classification; verify table-driven tests cover passed, failed, waiting, missing, skipped, cancelled, timed-out, stale, not-applicable, and disabled-policy states.
- [ ] 1.3 Add evaluator tests for candidate workflow changes, changed-file manifests, fork pull requests, draft pull requests, superseded revisions, duplicate check names, and stale results; verify candidate-controlled policy cannot change the expected validation set.

## 2. Base-owned aggregate workflow

- [ ] 2.1 Add the base-owned `pull_request_target` workflow for `ci-gate` with explicit pull-request event types, read-only permissions, immutable default-branch enforcement source, bounded timeout, and concurrency cancellation; verify workflow inspection shows no candidate checkout or candidate-code execution.
- [ ] 2.2 Implement the GitHub API polling adapter that reads the current pull request head SHA, trusted changed-file list, repository variable state, workflow runs, and check runs; verify it ignores results from earlier revisions, other pull requests, unexpected sources, and unrelated display-name collisions.
- [ ] 2.3 Publish the stable `ci-gate` job result and diagnostic summary for every evaluated state; verify the summary distinguishes validation success, failure, waiting, cancellation, timeout, non-applicability, and macOS-disabled policy without presenting disabled coverage as a test pass.

## 3. Existing workflow integration and cost controls

- [ ] 3.1 Reconcile the pull-request workflow triggers, path filters, job conditions, check names, and prerequisites with the trusted policy; verify lightweight checks remain observable, macOS work is not initiated for non-applicable changes, and applicable missing or skipped work cannot produce a passing gate.
- [ ] 3.2 Preserve or add concurrency groups that cancel superseded pull-request revisions and ensure cancelled older results cannot satisfy the newer revision; verify the behavior with workflow configuration tests and simulated check histories.
- [ ] 3.3 Preserve `ENABLE_MACOSX_JOBS=false` as a trusted repository-level opt-out for pull-request macOS validation while retaining manual or non-pull-request workflows where appropriate; verify a relevant pull request passes only with an explicit disabled-policy diagnostic and all other applicable validations passing.
- [ ] 3.4 Keep privileged validators base-owned and candidate execution unprivileged; verify workflow permissions, checkout refs, action pins, and candidate-code execution boundaries with static workflow tests.

## 4. Repository guidance and merge-control contract

- [ ] 4.1 Document the strict CI gate, applicability policy, disabled macOS behavior, short-circuit semantics, reviewer diagnostics, and enforcement-file ownership in the repository's internal CI/OpenSpec guidance; verify the documentation matches the workflow and policy tests.
- [ ] 4.2 Document the external `main` ruleset transition from individual job contexts to the `ci-gate` context, including GitHub Actions source enforcement, code-owner review, stale-review dismissal, and latest-push approval; verify the documented API/UI procedure matches the repository's current ruleset shape.
- [ ] 4.3 Record the incompatibility between latest-push approval and atomic stacked merges and define the required human reapproval or revised stack procedure; verify the guidance preserves the no-force-push rule.

## 5. Validation and evidence

- [ ] 5.1 Run the gate evaluator regression suite and workflow-structure tests; verify all policy-state and security-boundary scenarios pass.
- [ ] 5.2 Run `openspec validate --all --strict`, `make no-fixed-width-prose`, workflow/YAML validation, and the repository's applicable lint and documentation checks; record exact results and distinguish passed, skipped, blocked, and infrastructure-failed checks.
- [ ] 5.3 Perform read-only GitHub verification of registered workflows, recent check names, the repository variable, and the `main` ruleset; verify the evidence identifies which external ruleset changes remain manual and does not claim unperformed production enforcement.
