## 1. Contract and preflight

- [x] 1.1 Rewrite the proposal, specification, design, tasks, and QA evidence for the native reusable-workflow DAG and verify `openspec validate --all --strict` accepts coherent artifacts.
- [x] 1.2 Implement the tested Git preflight that selects `required`, `disabled-policy`, or `not-applicable` from the stack-base-to-head diff and trusted repository variable, and verify documentation-only, source, build, enforcement, unknown path, exact false, true, missing, malformed, stack-base, and invalid-revision cases.

## 2. Reusable validation workflows

- [x] 2.1 Add `workflow_call` entry points to PR description, OpenSpec validation, no-code-comments, fixed-width prose, formatting, lint, documentation, package resolution, unit-test, UI-test, and compatibility workflows, preserve applicable non-PR triggers, and verify every required validation is callable locally.
- [x] 2.2 Remove the title-based WIP action, keep OpenSpec guide comments and label application in separate best-effort automation, and verify neither is a required caller dependency.
- [x] 2.3 Preserve empty default permissions, job-level least privilege, full-SHA action pins, disabled checkout credentials, and PR-scoped concurrency, and verify the security contract test passes.

## 3. Native caller and gate

- [x] 3.1 Replace the API-polling `ci-gate` workflow with one ordinary `pull_request` caller filtered to the `main` stack trunk, invoke every reusable validation as a caller job, and verify the caller has no legacy direct validation triggers.
- [x] 3.2 Connect every macOS caller to preflight and all lightweight callers, condition them on `macos_mode=required` and successful prerequisites, and verify prerequisite failures short-circuit macOS work without passing the gate.
- [x] 3.3 Add the final `ci-gate` job with `if: always()`, all caller dependencies, explicit intentional-skip handling, and a summary of preflight mode and native job results, and verify failed, cancelled, skipped, disabled-policy, and not-applicable states.
- [x] 3.4 Delete the policy JSON, API adapter, evaluator, polling workflow code, integration tests, and obsolete guidance tests, and verify no removed identifier or cross-run polling remains.

## 4. Guidance, stack, and ruleset migration

- [x] 4.1 Rewrite internal CI/OpenSpec guidance and QA evidence for the native DAG, disabled macOS policy, short-circuit behavior, reviewer diagnostics, and manual rollback, and verify prose and guidance tests pass.
- [ ] 4.2 Restructure the formal stack to revised proposal #353, one replacement implementation layer, guidance #358, QA #359, and archive #361 with `gh stack modify` and `gh stack submit`, and verify formal metadata plus every immediate PR base.
- [ ] 4.3 After a real `ci-gate` result exists and with explicit owner approval, capture and update the live ruleset so only GitHub Actions `ci-gate` is required while review, thread, squash, and history protections remain unchanged; verify the complete ruleset readback or document the external blocker.

## 5. Validation and evidence

- [x] 5.1 Run the preflight and workflow-contract suites plus all applicable repository checks, and record passed, skipped, blocked, and infrastructure-failed results without claiming skipped macOS validation passed.
- [x] 5.2 Run `make xcodeproj && make test-ui-dev`, screenshots, and `git diff --check` under the approved isolated environment, or record the exact infrastructure blocker and keep it separate from code failures.
- [ ] 5.3 Verify retained stack-layer GitHub runs, repository variable state, current head results, and the final live ruleset state, and record exact evidence before considering the change complete.
