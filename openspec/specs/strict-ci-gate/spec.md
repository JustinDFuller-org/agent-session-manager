# strict-ci-gate Specification

## Purpose

The strict CI gate gives pull requests one trusted, reviewable merge result while preserving deliberate cost controls for expensive macOS validation and preventing candidate-controlled workflow conditions from silently converting missing validation into success.

## Requirements

### Requirement: Pull requests have one authoritative CI gate

The repository SHALL publish a stable `ci-gate` result for every pull request event covered by the repository's merge policy, including draft pull requests, opened and updated pull requests, reopened pull requests, edited pull-request metadata, and pull requests from forks. The result SHALL identify the head SHA it evaluated.

#### Scenario: Pull request reaches a gateable revision

- **WHEN** a pull request is opened, updated, reopened, changes draft state, or has its gate-relevant metadata edited
- **THEN** the repository publishes a `ci-gate` result for that pull request's current head revision

#### Scenario: Pull request head advances while validation is running

- **WHEN** a newer head revision replaces the revision being evaluated
- **THEN** the older evaluation is cancelled or rendered obsolete and cannot satisfy the gate for the newer revision

### Requirement: Applicability is determined by trusted policy

The `ci-gate` result SHALL evaluate a base-owned validation matrix containing every pull-request validation, its canonical workflow and job identity, its trigger expectations, its changed-file applicability categories, and its prerequisite relationships. The matrix SHALL distinguish validations that apply to every pull request from validations that apply only to selected changed-file categories. Candidate-controlled workflow conditions, path filters, labels, inputs, and generated status names SHALL NOT determine whether a required validation applies.

The policy SHALL classify the following categories at minimum:

- Pull-request metadata and enforcement validations that apply to every gateable revision, subject to an explicitly documented same-repository or fork limitation.
- Lightweight Ubuntu source, format, lint, package, documentation, and OpenSpec validations that apply according to the repository's pull-request policy.
- macOS unit, UI, and dependency/toolchain compatibility validations for source, test, package, project, build, app-resource, toolchain, or enforcement changes.
- Release, scheduled, manual-only, Dependabot, screenshot-publication, and post-merge automation that is excluded from pull-request merge accounting.

The policy SHALL use an explicit allowlist for non-applicable macOS-only changes. A path that is not classified, a manifest that is incomplete, or a policy entry that cannot be resolved SHALL make the related validation applicable or make the gate fail closed; it SHALL NOT silently make validation not applicable.

#### Scenario: Candidate changes a workflow condition

- **WHEN** a pull request changes a workflow condition that would suppress an applicable validation
- **THEN** the `ci-gate` result still evaluates applicability using the default-branch policy and the trusted changed-file set

#### Scenario: Candidate changes only explicitly non-applicable content

- **WHEN** the complete trusted changed-file set contains only paths in a validation's documented non-applicable allowlist
- **THEN** that validation is reported as not applicable and does not block the pull request

#### Scenario: Changed-file classification is incomplete

- **WHEN** the changed-file API response is truncated, exceeds the supported manifest ceiling, cannot be fully paginated, or contains a path the policy cannot classify
- **THEN** the gate fails closed and identifies the incomplete or unknown policy input

### Requirement: Applicable validation identity is exact

When a validation is applicable and macOS validation is enabled, `ci-gate` SHALL require a successful result for the current pull request head SHA from the expected GitHub Actions integration, workflow, and job identity in the trusted validation matrix. Results from an earlier revision, another pull request, an unexpected check source, a non-GitHub Actions integration, or an unrelated check with the same display name SHALL NOT satisfy the requirement. Missing or ambiguous identity mappings SHALL fail closed.

#### Scenario: Applicable validation succeeds on the current revision

- **WHEN** every applicable validation reports success for the current pull request head revision with the expected provenance
- **THEN** `ci-gate` reports success

#### Scenario: Applicable validation is missing or unsuccessful

- **WHEN** an applicable validation is missing, queued beyond the gate timeout, skipped, cancelled, timed out, neutral, or unsuccessful
- **THEN** `ci-gate` reports failure and identifies the validation that prevented success

#### Scenario: Same-name result has unexpected provenance

- **WHEN** a check with the expected display name is attached to the head SHA by an unexpected integration or workflow identity
- **THEN** the result does not satisfy the validation and `ci-gate` reports a provenance failure

### Requirement: Disabled macOS validation is an explicit opt-out

When the trusted repository variable `ENABLE_MACOSX_JOBS` is exactly `false`, the repository SHALL NOT require or initiate pull-request macOS validation, and `ci-gate` SHALL report the disabled policy as an explicit non-error decision. Any missing, malformed, or unavailable value SHALL be treated as macOS validation enabled. The value SHALL be read from trusted repository configuration rather than pull-request content.

#### Scenario: Relevant pull request while macOS validation is disabled

- **WHEN** the changed-file policy would otherwise require macOS validation and `ENABLE_MACOSX_JOBS` is exactly `false`
- **THEN** no macOS result is required or initiated for merge, `ci-gate` reports that macOS validation was disabled by repository policy, and the pull request may pass only if all other applicable validations succeed

#### Scenario: Variable is missing or malformed

- **WHEN** `ENABLE_MACOSX_JOBS` is absent or has a value other than the exact supported boolean values
- **THEN** the gate treats macOS validation as enabled and requires the applicable macOS result

#### Scenario: Candidate attempts to enable or disable macOS validation

- **WHEN** a pull request changes workflow YAML, scripts, labels, inputs, or other candidate-controlled content related to `ENABLE_MACOSX_JOBS`
- **THEN** the candidate content does not change the value used by `ci-gate`

### Requirement: Expensive validation can short-circuit without passing

The repository SHALL avoid starting applicable macOS validation after a decisive required prerequisite has failed, while preserving a failing `ci-gate` result until the prerequisite is repaired and the applicable validation succeeds or the trusted macOS opt-out is active. Short-circuiting SHALL be represented as a failed or blocked validation state, not as success or not applicable.

#### Scenario: Cheap prerequisite fails before macOS validation starts

- **WHEN** an applicable lightweight validation fails before macOS validation begins
- **THEN** the macOS work is not started for that revision and `ci-gate` remains unsuccessful with the prerequisite failure identified

#### Scenario: Superseded run is cancelled

- **WHEN** a newer pull request revision supersedes an in-progress validation run
- **THEN** the older run is cancelled or ignored and cannot satisfy `ci-gate` for the newer revision

### Requirement: Gate diagnostics distinguish policy from validation

The `ci-gate` result SHALL identify each matrix entry as passed, failed, waiting, cancelled, skipped, timed out, not applicable, disabled by trusted macOS policy, or blocked by a prerequisite. A disabled macOS validation SHALL NOT be represented as a successful test result. The summary SHALL identify the evaluated head SHA, policy revision or source, and any incomplete input.

#### Scenario: Reviewer inspects a passing gate with macOS disabled

- **WHEN** `ci-gate` succeeds while `ENABLE_MACOSX_JOBS` is exactly `false`
- **THEN** the check summary shows that macOS validation was intentionally disabled and lists the remaining applicable validations that passed

#### Scenario: Reviewer inspects a blocked gate

- **WHEN** `ci-gate` fails or waits for validation
- **THEN** the check summary names the missing or unsuccessful validation, its observed state and provenance, and the current head revision being evaluated

### Requirement: Merge controls enforce the trusted gate

The protected default branch SHALL require the `ci-gate` result from the expected GitHub Actions integration, use strict required-status enforcement, preserve code-owner review and thread-resolution requirements, and reject a merge without a successful `ci-gate` result for the current revision. Individual conditional validation jobs SHALL NOT be the sole merge requirement.

The gate migration SHALL preserve the repository's existing review settings unless a separately approved, stack-compatible migration enables stale-review dismissal or latest-push approval. Any such future review-policy change SHALL require a verified merge procedure that does not rely on force-pushing and shall be documented before activation.

#### Scenario: Required gate has not passed

- **WHEN** a pull request lacks a successful `ci-gate` result for its current revision
- **THEN** the protected default branch rejects the merge

#### Scenario: New push follows approval

- **WHEN** a new commit is pushed after a human approval
- **THEN** the gate is reevaluated for the new revision, and the repository's configured review policy determines whether the prior approval remains sufficient

#### Scenario: Latest-push approval is proposed for activation

- **WHEN** the repository considers enabling latest-push approval while using stacked or atomic merges
- **THEN** activation is withheld until the merge procedure is demonstrated to preserve a valid latest-revision approval without force-pushing or silently weakening the protection
