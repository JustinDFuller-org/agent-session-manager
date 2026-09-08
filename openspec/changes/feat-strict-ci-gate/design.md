## Context

The repository currently has separate pull-request workflows for description and WIP checks, OpenSpec validation, prose and code-comment scanning, formatting, linting, documentation, package resolution, unit tests, UI tests, and dependency/toolchain compatibility. The current `main` ruleset requires several job contexts directly, including macOS jobs whose job-level condition reports success when `ENABLE_MACOSX_JOBS` is `false`, while other pull-request workflows are not required. The existing OpenSpec and no-code-comments workflows establish the trusted pattern of running validator logic from the default branch against an immutable candidate revision.

The design must account for GitHub Actions behavior at the workflow, job, check-run, ruleset, and pull-request event layers. A pull-request workflow can be changed by the candidate, checks can be skipped by conditions, and independent workflows cannot be ordered with `needs`. The aggregate gate therefore needs a trusted policy source, exact result identity, bounded API reads, and an explicit distinction between validation evidence and policy decisions.

## Goals / Non-Goals

**Goals:**

- Make one base-owned `ci-gate` result the authoritative pull-request merge signal.
- Evaluate applicability and check provenance for the exact pull-request head revision using a complete trusted changed-file manifest.
- Keep candidate workflow execution separate from gate authority and prevent candidate policy from deciding whether validation applies.
- Avoid macOS work for non-applicable changes, preserve cancellation of superseded revisions, and allow an explicit trusted macOS opt-out when `ENABLE_MACOSX_JOBS` is exactly `false`.
- Give reviewers actionable diagnostics that distinguish passed, failed, waiting, skipped, cancelled, timed-out, not-applicable, disabled-policy, and prerequisite-blocked states.
- Keep the implementation and all production workflow integration in scope for a later implementation session; this change defines the complete contract and implementation sequence.

**Non-Goals:**

- Proving the semantic correctness of candidate code or preventing a contributor who receives human approval from changing the test harness itself.
- Automatically changing GitHub rulesets, repository variables, CODEOWNERS, bypass actors, or review settings.
- Replacing the existing OpenSpec, no-code-comments, fixed-width-prose, release, scheduled, or Dependabot policies.
- Enabling stale-review dismissal or latest-push approval without a separately verified procedure for the repository's stacked and atomic merge workflows.

## Decisions

### Use a base-owned pull-request waiter

Add a base-owned `pull_request_target` workflow whose definition and evaluator are taken from the default branch. It will handle `opened`, `reopened`, `synchronize`, `ready_for_review`, `converted_to_draft`, and `edited` events. The `edited` event is required because a gate-relevant pull-request body or metadata change must not leave a stale result authoritative.

The workflow will use read-only GitHub API access to obtain the trusted pull-request head and base SHAs, the complete changed-file manifest, repository variable state, workflow runs, check runs, and the base-owned policy. It will not check out or execute candidate scripts, workflow files, package manifests, tests, or build commands. Its own run will be concurrency-scoped to the repository and pull request, with cancellation for superseded revisions and a bounded polling timeout.

An event-driven `workflow_run` aggregator was considered because it can reduce waiting runner minutes. The selected waiter keeps the state machine and required check lifecycle in one visible job and avoids treating candidate-controlled workflow artifacts as privileged inputs. The evaluator remains bounded so observed usage can justify a future event-driven design without making that a prerequisite for this change.

### Define a base-owned validation matrix

Create one policy manifest in the enforcement surface. It must be read from the base revision and must contain canonical workflow/job identities, expected GitHub Actions integration, pull-request trigger expectations, applicability categories, prerequisite relationships, and whether an entry is excluded from pull-request accounting.

The initial matrix covers the current pull-request surface as follows:

| Matrix entry | Applicability | Provenance and trigger expectation |
| --- | --- | --- |
| `PR Description Check`, `WIP Check` from `PR Quality` | Every gateable pull request, with documented handling for fork metadata permissions | `pull_request` workflow jobs `pr-description` and `wip-check` |
| `openspec-guide` from `OpenSpec Guide` | Same-repository pull requests; fork behavior is reported as not applicable because the current job intentionally excludes forks | Base-owned `pull_request_target` job `openspec-guide`, evaluating candidate OpenSpec data without executing candidate code |
| `openspec-check` and `openspec-label` from `OpenSpec` | `openspec-check` applies to every gateable pull request; `openspec-label` applies only to same-repository pull requests | Base-owned `pull_request_target` jobs `openspec-check` and `openspec-label`, evaluating immutable candidate data without executing candidate code |
| `no-code-comments` from `No Code Comments` and `no-fixed-width-prose` from `Fixed-width Prose` | Every gateable pull request; fixed-width prose must include metadata edits | Base-owned `pull_request_target` jobs `no-code-comments` and `no-fixed-width-prose`, evaluating immutable candidate data without executing candidate code |
| `swift-format check` from `Format`, `SwiftLint` from `Lint`, `Jekyll build and link check` from `Documentation`, and `swift package resolve` from `Swift Build Check` | Every applicable pull-request revision according to the repository policy; no candidate path filter may remove a required entry | `pull_request` jobs `swift-format`, `swiftlint`, `docs-check`, and `resolve` respectively |
| `swift test` from `Unit Tests` and `make test-ui-dev-launch` from `UI Tests` | Changes to `Sources/**`, `Tests/**`, `UITests/**`, `Package.swift`, `Package.resolved`, `project.yml`, build settings, app resources, toolchain files, `Makefile`, or `.github/**`, plus any future paths explicitly added to the manifest | `pull_request` jobs `test` in the respective workflows; applicability is additionally gated by trusted `ENABLE_MACOSX_JOBS` |
| `Dependency and toolchain compatibility` job `compatibility` | Changes to package manifests or resolution, project/build configuration, source and test trees, toolchain declarations, build scripts, or enforcement files | `pull_request` job `compatibility`; applicability is additionally gated by trusted `ENABLE_MACOSX_JOBS` |
| Release, scheduled, manual-only, Dependabot, screenshot-publication, and post-merge automation | Never part of pull-request merge accounting unless explicitly added to the matrix | Their own event and workflow identities remain independent |

The policy must also define the explicit non-applicable allowlist for macOS-only validation, initially limited to documentation-only and other repository paths proven not to affect the application, package, build, test, toolchain, resources, or enforcement surface. The implementation must encode the allowlist as data and test it. Unknown paths, an incomplete changed-file response, an unrecognized policy version, or conflicting matrix entries fail closed rather than becoming not applicable.

### Read the complete changed-file manifest safely

The evaluator will paginate the pull-request files endpoint with a bounded page size and will require proof that all pages were read. It will enforce a documented maximum supported changed-file count. A response that reaches the API's truncation boundary, fails pagination, or cannot establish completeness is a gate error, not a reason to skip validation. The implementation will not rely on a single summary `changed_files` count as the manifest.

The evaluator will read the pull request's current head SHA and base SHA from the API response and will re-check the head before publishing the result. If the head changes during evaluation, the run will stop or retry against the new revision and will not publish a result that claims to evaluate the old revision as current.

### Keep validation execution separate from gate authority

Candidate-execution workflows will continue to run through `pull_request` with no secrets and the minimum permissions needed for their tasks. Existing base-owned validators will continue to use immutable candidate data without executing candidate code. The gate will observe their results but will not trust their workflow conditions, path filters, check names, or generated policy.

Changes to enforcement workflows, scripts, and the policy manifest remain subject to human review through the repository's ownership rules. The privileged workflow must use only base-revision source and read-only permissions. Action references in the new enforcement surface must be pinned according to the repository's security policy.

### Require exact result provenance

The policy stores the expected workflow identity, job identity, event expectation, and GitHub Actions integration for each matrix entry. The evaluator matches check runs to the current head SHA and expected integration, then matches workflow runs and jobs to the expected workflow and job identity. A display-name match alone is insufficient. Duplicate, ambiguous, stale, non-GitHub, or otherwise unexpected results fail closed.

The evaluator classifies check conclusions and workflow/job states into the contract's terminal states. `success` is the only validation state that satisfies an applicable entry. `queued`, `in_progress`, and an absent result remain waiting until the bounded timeout; `skipped`, `cancelled`, `timed_out`, `neutral`, and failure conclusions block the gate. A prerequisite-blocked macOS entry is reported as blocked while the gate remains unsuccessful.

### Interpret `ENABLE_MACOSX_JOBS` as a trusted opt-out

The gate reads `ENABLE_MACOSX_JOBS` from trusted repository configuration in the privileged event. Exact `true` enables applicable macOS validation. Exact `false` disables initiation and requirement of pull-request macOS validation and produces a distinct disabled-policy diagnostic. Missing, malformed, or unavailable values are treated as enabled so an operational lookup failure cannot reduce coverage.

The repository variable is not a candidate input. Candidate changes to workflow YAML, scripts, labels, inputs, or any other pull-request content cannot change the value used by the gate. Manual or non-pull-request macOS workflows may remain available; the opt-out applies only to the pull-request validations represented in the matrix.

### Short-circuit expensive work without weakening the merge result

Where the existing workflow structure permits it, lightweight prerequisites will run before expensive macOS jobs using native workflow dependencies. A prerequisite failure may prevent a macOS job from starting, but the gate records the macOS entry as blocked and the prerequisite as failed. It does not convert either state to success or not applicable.

Workflow-level concurrency cancels superseded pull-request validation runs. The gate's own concurrency cancels its older waiter. The evaluator never accepts a cancelled or completed result whose head SHA differs from the current revision, so cancellation cannot create a passing status for a newer revision.

### Migrate the ruleset in a controlled sequence

The target protected-branch configuration requires the `ci-gate` check from the expected GitHub Actions integration with strict required-status enforcement. It preserves code-owner review and thread resolution. The initial migration does not silently change unrelated review settings.

Stale-review dismissal and latest-push approval are intentionally treated as separate external policy changes. The live repository currently uses a stacked/atomic merge workflow for some changes, and latest-push approval can invalidate approvals as the merge base changes. Before either setting is enabled, the repository must document and verify a stack-compatible merge procedure that does not force-push or weaken protection. Workflow code cannot make that ruleset change.

### Use visible diagnostics as the contract

The `ci-gate` job summary and check output will show the evaluated head SHA, base-owned policy source/version, each matrix entry, applicability reason, expected provenance, observed state, and final decision. It will show disabled macOS policy as a policy decision rather than a successful validation and will identify the changed-file or API completeness error when it fails closed.

## Risks / Trade-offs

- [Risk] A privileged waiter could become a pull-request execution boundary if it checks out or evaluates candidate code. -> Keep the workflow and evaluator base-owned, use API data only, set read-only permissions, pin actions, and add static tests that reject candidate-source execution.
- [Risk] Polling consumes Ubuntu runner minutes while macOS jobs are running. -> Bound the polling interval and timeout, cancel superseded revisions, and keep the waiter free of candidate build work; revisit an event-driven aggregator if observed usage is material.
- [Risk] `ENABLE_MACOSX_JOBS=false` allows a relevant pull request to merge without macOS evidence. -> Require trusted repository configuration, treat malformed values as enabled, show the opt-out prominently in the gate summary, and preserve all non-macOS validations.
- [Risk] A candidate can still change tests or build inputs that it is authorized to modify. -> Keep human review of the enforcement surface, require the gate for the current revision, and treat the gate as enforcement of CI policy rather than proof of semantic correctness.
- [Risk] Exact job identities and workflow sources can drift as workflows evolve. -> Centralize the expected identities in the base-owned policy, test the mapping, and make unknown or duplicate results fail closed.
- [Risk] GitHub's changed-file API can return an incomplete manifest at its documented limit. -> Paginate explicitly, enforce a supported ceiling, and fail closed when completeness cannot be established.
- [Risk] Ruleset review changes can conflict with atomic stacked merges. -> Keep those changes separate from gate activation, document the conflict, preserve the no-force-push rule, and require explicit owner approval for any later review-policy migration.

## Migration Plan

1. Add the policy manifest and pure evaluator with fixtures for every matrix state, changed-file classification, exact-SHA/provenance case, fork and draft event, edited metadata event, incomplete manifest, malformed variable, and superseded revision.
2. Add the base-owned `ci-gate` workflow and API adapter with read-only permissions, base-revision source, bounded pagination, timeout, concurrency cancellation, and diagnostic output. Verify its static security boundary before enabling any external required check.
3. Reconcile candidate-execution workflows with the matrix. Preserve non-pull-request triggers, use native prerequisites for cost control, and ensure candidate path filters are optimizations only.
4. Validate the complete change locally and in a disposable pull request, including workflow structure, policy/evaluator tests, OpenSpec, fixed-width prose, lint, and applicable repository checks. Record skipped, blocked, and infrastructure-failed checks distinctly.
5. After the implementation is reviewed and available on the default branch, a repository owner manually registers the `ci-gate` context from the expected GitHub Actions integration and removes the old individual required contexts. The owner verifies the live ruleset and performs a rollback by restoring the prior required contexts if the new gate is unavailable.
6. Treat latest-push approval and stale-review dismissal as a later, separately approved migration only after a stack-compatible procedure has been demonstrated and documented.
