## Context

The repository currently has separate pull-request workflows for description and WIP checks, OpenSpec validation, prose and code-comment scanning, formatting, linting, documentation, package resolution, unit tests, UI tests, and dependency/toolchain compatibility. The current `main` ruleset requires several job contexts directly, including macOS jobs whose job-level condition reports success when `ENABLE_MACOSX_JOBS` is `false`, while other pull-request workflows are not required. The existing OpenSpec and no-code-comments workflows already establish the trusted pattern of running validator logic from the default branch against an immutable candidate revision.

## Goals / Non-Goals

**Goals:**

- Make one base-owned `ci-gate` result the authoritative pull-request merge signal.
- Evaluate applicability and check provenance for the exact pull-request head revision.
- Keep candidate workflow execution separate from the privileged gate and prevent candidate policy from deciding whether validation applies.
- Avoid macOS work for non-applicable changes, preserve cancellation of superseded revisions, and allow an explicit trusted macOS opt-out when `ENABLE_MACOSX_JOBS` is `false`.
- Give reviewers actionable diagnostics that distinguish passed, failed, waiting, skipped, cancelled, timed-out, not-applicable, and disabled-policy states.

**Non-Goals:**

- Proving the semantic correctness of candidate code or preventing a contributor who receives human approval from changing the test harness itself.
- Automatically changing GitHub rulesets, repository variables, CODEOWNERS, bypass actors, or review settings.
- Replacing the existing OpenSpec, no-code-comments, fixed-width-prose, release, scheduled, or Dependabot policies.

## Decisions

### Use a base-owned `pull_request_target` waiter

Add a base-owned pull-request workflow whose definition and evaluator are taken from the default branch. It will use read-only GitHub API access to obtain the trusted changed-file manifest, repository variable state, workflow runs, and check runs for the current head SHA. It will not check out or execute candidate scripts, workflow files, package manifests, tests, or build commands.

An event-driven `workflow_run` aggregator was considered because it would use fewer waiting runner minutes, but the selected waiter keeps the state machine and required check lifecycle in one visible job. Its polling interval, overall timeout, and concurrency group will be bounded so it cannot wait indefinitely or continue spending time on superseded revisions.

### Keep validation execution separate from gate authority

Candidate-execution workflows will continue to run through `pull_request` with no secrets and the minimum read permissions needed for their tasks. The gate will observe their results but will not trust their workflow conditions, path filters, check names, or generated policy. Base-owned validators such as OpenSpec and no-code-comments will continue to use immutable candidate data without executing candidate code.

This preserves GitHub's security boundary for `pull_request_target`: privileged workflow code remains base-owned, and candidate code is never executed from that event. Changes to enforcement workflows and scripts remain subject to the repository's human CODEOWNERS and latest-push review boundary.

### Define applicability in a base-owned policy manifest

Create one explicit policy source in the enforcement surface that maps validation contexts to changed-file categories and trigger expectations. Lightweight Ubuntu validations will remain applicable to pull requests according to their current repository policy. MacOS unit tests, UI tests, and dependency/toolchain compatibility will apply to source, test, package, project, build, app-resource, toolchain, or enforcement changes identified by the policy. Release, scheduled maintenance, manual-only, and Dependabot automation will remain outside pull-request merge accounting.

The policy will treat any missing result as a failure when the validation applies. A workflow or job may use path filtering or a prerequisite short-circuit to save work, but that optimization cannot turn an applicable missing or skipped result into success. The evaluator will report a validation as not applicable only when the trusted policy says so.

### Interpret `ENABLE_MACOSX_JOBS` as a trusted opt-out

The gate will read `ENABLE_MACOSX_JOBS` from repository configuration in the privileged event. When the value is `true`, applicable macOS validations must complete successfully unless an earlier decisive prerequisite has failed, in which case the gate remains failing and reports the prerequisite. When the value is `false`, the gate will not require or initiate pull-request macOS validation, will record the policy decision explicitly, and may succeed if all other applicable validations pass.

The opt-out is intentionally not represented as a test success. This preserves reviewer visibility and makes the coverage reduction distinguishable from a passed macOS run.

### Aggregate exact-SHA results into one stable check

The gate job will be named `ci-gate` and will evaluate only results attached to the current pull-request head SHA. It will require the expected GitHub Actions source and the configured validation identity rather than accepting an arbitrary check with the same display name. It will fail for missing, skipped, cancelled, timed-out, neutral, stale, or unsuccessful applicable results and will include the blocking state in the job summary.

The `main` ruleset will be migrated from individual conditional job contexts to the single `ci-gate` context after the new workflow is available. The ruleset will retain code-owner review and thread resolution, dismiss stale approvals on new pushes, and require approval of the latest reviewable push. The latest-push setting improves post-approval integrity but may require a fresh human approval after stacked branch updates.

### Short-circuit expensive work without weakening the merge result

Lightweight prerequisites will run before expensive macOS work where the existing workflow structure permits it. If a prerequisite fails, downstream macOS work may be cancelled or not started, but the gate will remain unsuccessful. A newer revision will cancel older in-progress runs through workflow concurrency, and cancelled older results will never satisfy the newer revision's gate.

## Risks / Trade-offs

- [Risk] A privileged waiter could become a pull-request execution boundary if it checks out or evaluates candidate code. -> Keep the workflow and evaluator base-owned, use API data only, set read-only permissions, and add tests that reject candidate-source execution.
- [Risk] Polling consumes Ubuntu runner minutes while macOS jobs are running. -> Bound the polling interval and timeout, cancel superseded runs, and keep the waiter free of candidate build work; revisit an event-driven aggregator if observed usage is material.
- [Risk] `ENABLE_MACOSX_JOBS=false` allows a relevant pull request to merge without macOS evidence. -> Require trusted repository configuration, show the opt-out prominently in the gate summary, and preserve all non-macOS validations.
- [Risk] A candidate can still change tests or build inputs that it is authorized to modify. -> Keep human review of the enforcement surface, require approval of the latest push, and treat the gate as enforcement of CI policy rather than proof of semantic correctness.
- [Risk] Exact job names and workflow sources can drift as workflows evolve. -> Centralize the expected identities in the base-owned policy, test the mapping, and make unknown or duplicate results fail closed.
- [Risk] Requiring latest-push approval conflicts with the repository's atomic stacked-merge workflow. -> Document the conflict, preserve the no-force-push rule, and require an explicit human reapproval or revised stack merge procedure rather than silently weakening the rule.
