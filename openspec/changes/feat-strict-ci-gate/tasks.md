## 1. Trusted policy and evaluator contract

- [x] 1.1 Define the base-owned validation matrix with canonical workflow/job/integration identities, pull-request trigger expectations, every-current-validation coverage, changed-file categories, an explicit macOS non-applicable allowlist, prerequisite relationships, and excluded automation; verify unknown paths, conflicting entries, and missing policy data fail closed.
- [x] 1.2 Implement pure gate-evaluation logic for applicability, complete changed-file manifests, exact-head matching, expected GitHub Actions provenance, repository-variable parsing, and terminal result classification; verify table-driven tests cover passed, failed, waiting, missing, skipped, cancelled, timed-out, neutral, stale, not-applicable, prerequisite-blocked, and disabled-policy states.
- [x] 1.3 Add evaluator fixtures for candidate workflow changes, changed-file pagination and truncation, fork pull requests, draft pull requests, edited metadata events, superseded revisions, duplicate check names, unexpected integrations, stale results, and malformed `ENABLE_MACOSX_JOBS`; verify candidate-controlled policy cannot change the expected validation set.

## 2. Base-owned aggregate workflow

- [x] 2.1 Add the base-owned `pull_request_target` workflow for `ci-gate` with `opened`, `reopened`, `synchronize`, `ready_for_review`, `converted_to_draft`, and `edited` events, read-only permissions, immutable default-branch enforcement source, bounded timeout, and concurrency cancellation; verify workflow inspection shows no candidate checkout or candidate-code execution.
- [x] 2.2 Implement the GitHub API adapter that reads the current pull-request head and base SHAs, the complete paginated changed-file list, trusted repository variable state, workflow runs, check runs, and jobs; verify it enforces the changed-file ceiling and ignores earlier revisions, other pull requests, unexpected sources, and unrelated display-name collisions.
- [x] 2.3 Publish the stable `ci-gate` job result and diagnostic summary for every evaluated state; verify the summary includes head SHA, policy source/version, applicability reasons, expected and observed provenance, validation state, incomplete-input failures, and macOS-disabled policy without presenting disabled coverage as a test pass.

## 3. Existing workflow integration and cost controls

- [x] 3.1 Reconcile the pull-request workflow triggers, path filters, job conditions, check names, and prerequisites with the trusted matrix; verify lightweight checks remain observable, macOS work is not initiated for explicitly non-applicable changes, and applicable missing or skipped work cannot produce a passing gate.
- [x] 3.2 Preserve or add workflow and gate concurrency groups that cancel superseded pull-request revisions; verify cancelled older results cannot satisfy the newer revision with workflow-structure tests and simulated check histories.
- [x] 3.3 Preserve `ENABLE_MACOSX_JOBS=false` as a trusted repository-level opt-out for pull-request macOS validation while retaining manual or non-pull-request workflows where appropriate; verify exact `false` produces an explicit disabled-policy diagnostic, while missing or malformed values require applicable macOS validation.
- [x] 3.4 Keep privileged validators base-owned and candidate execution unprivileged; verify workflow permissions, base checkout refs, action pins, trigger separation, and candidate-code execution boundaries with static workflow tests.

## 4. Repository guidance and merge-control contract

- [ ] 4.1 Document the strict CI gate, complete applicability matrix, changed-file failure modes, disabled macOS behavior, short-circuit semantics, reviewer diagnostics, and enforcement-file ownership in the repository's internal CI/OpenSpec guidance; verify the documentation matches the workflow and policy tests.
- [ ] 4.2 Document the external `main` ruleset transition from individual job contexts to the `ci-gate` context, including the expected GitHub Actions integration, strict status enforcement, code-owner review, and thread resolution; verify the documented API/UI procedure matches the intended ruleset shape and explicitly identifies manual steps.
- [ ] 4.3 Record the incompatibility risk between latest-push or stale-review requirements and atomic stacked merges; verify the guidance preserves the no-force-push rule and requires a separately verified, owner-approved merge procedure before either review setting changes.

## 5. Validation and evidence

- [ ] 5.1 Run the gate evaluator regression suite and workflow-structure/security tests; verify all policy-state, exact-provenance, pagination, event, and security-boundary scenarios pass.
- [ ] 5.2 Run `openspec validate --all --strict`, `make no-fixed-width-prose`, workflow/YAML validation, and the repository's applicable lint and documentation checks; record exact results and distinguish passed, skipped, blocked, and infrastructure-failed checks.
- [ ] 5.3 Perform read-only verification in a disposable pull request or equivalent fixture-driven harness for registered workflow identities, current check conclusions, fork/draft/edited event behavior, the repository variable, and the target ruleset contract; verify the evidence does not claim live production enforcement until the external ruleset migration is manually completed.
