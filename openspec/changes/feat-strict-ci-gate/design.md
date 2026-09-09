## Context

The existing change uses a `pull_request_target` workflow, a base-owned JSON policy, GitHub API pagination, check-run provenance matching, and a polling evaluator. The requested end state is a conventional pull-request workflow graph. GitHub evaluates stacked pull requests against the stack trunk, so a caller filtered to `branches: [main]` covers each formal layer while keeping the workflow in the pull-request event family.

## Goals / Non-Goals

**Goals:**

- Make reusable validation workflows the single source for each validation and make the caller's job graph the trusted applicability and prerequisite contract.
- Ensure expensive macOS jobs start only after the tested preflight selects `required` and every lightweight job succeeds.
- Ensure `ci-gate` always publishes a result and distinguishes required failures from intentional macOS skips.
- Preserve least-privilege permissions, SHA-pinned actions, disabled checkout credentials, PR-scoped cancellation, and non-PR entry points.
- Keep privileged OpenSpec guide and label automation separate from required validation.

**Non-Goals:**

- No application or Swift runtime changes.
- No API polling, check-run discovery, candidate-policy evaluation, or synthetic status taxonomy.
- No organization migration, required-workflow rule, stale-review rule, latest-push approval rule, or force-update of `main`.

## Decisions

### Use one caller workflow and local reusable workflows

Each validation workflow gains `workflow_call`; the caller invokes it directly as one job. The caller retains the pull-request event types and `branches: [main]` filter, while reusable workflows retain push, schedule, or manual triggers that are meaningful outside PR accounting. This uses GitHub's supported `jobs.<job_id>.uses` model and ensures every PR revision creates one coherent DAG. Duplicating all validation steps into a monolithic workflow was rejected because it would make the preserved non-PR entry points diverge.

### Encode applicability in preflight and caller conditions

The preflight checks the trusted stack-base SHA and current head SHA with Git, classifies changed paths against a small documented set of macOS-relevant categories, and writes `macos_mode` to `GITHUB_OUTPUT`. Documentation-only changes select `not-applicable`; exact repository variable value `false` selects `disabled-policy`; relevant changes select `required`; unknown paths, malformed variables, invalid revisions, or incomplete diffs fail closed. Candidate workflow conditions cannot alter this decision because the repository variable and SHAs come from the event and repository configuration.

### Use native `needs` results for the gate

The gate lists the preflight, every lightweight caller, and every macOS caller in `needs` and runs with `if: always()`. Its shell step accepts successful lightweight callers, accepts skipped macOS callers only for `disabled-policy` or `not-applicable`, and fails for any other failed, cancelled, or skipped required job. This follows GitHub's required-check guidance and avoids polling for statuses that the same workflow already owns.

### Keep best-effort automation outside the caller

The OpenSpec guide comment and label application remain in a separate `pull_request_target` workflow. They do not become caller jobs or gate dependencies. The title-based WIP action is removed because draft pull requests already have native merge protection and a title convention is not validation.

### Treat the ruleset migration as an external, reversible operation

Before changing required contexts, capture the complete live ruleset. After a real `ci-gate` context is registered, replace only the individual status requirements with the GitHub Actions `ci-gate` context while preserving strict status enforcement, code-owner approval, thread resolution, squash-only merging, non-fast-forward protection, and human bypass settings. If the gate is unavailable, restore the captured individual contexts. No operation force-updates `main`; rewritten feature branches may use `--force-with-lease` only when branch coverage is verified.

## Risks / Trade-offs

- [Candidate-controlled workflow definitions] → The repository accepts this trade-off because the required human and code-owner review remains in force; the caller's job graph, preflight, and gate are independently tested and the ruleset transition is owner-approved.
- [A changed path may be unknown to the classifier] → Unknown paths select required macOS validation rather than silently reducing coverage.
- [A lightweight failure prevents expensive diagnostics] → MacOS jobs are intentionally short-circuited, while `ci-gate` remains failed and names the prerequisite so repair reruns the complete DAG.
- [Every PR-body edit reruns the DAG] → This avoids stale success reuse and keeps the workflow free of cross-run correlation.
- [Repository macOS variable is currently false] → Relevant macOS jobs are reported as skipped with an explicit disabled-policy reason; this is not represented as a test pass.
- [The GitHub stacked-PR feature is preview behavior] → Keep the caller filter on the stack trunk, verify formal stack metadata and each immediate base, and retain a documented rollback procedure.
