## Purpose

The strict CI gate gives pull requests one trusted, reviewable merge result while preserving deliberate cost controls for expensive macOS validation and preventing candidate-controlled workflow conditions from silently converting missing validation into success.

## ADDED Requirements

### Requirement: Pull requests have one authoritative CI gate

The repository SHALL publish a stable `ci-gate` result for every pull request event covered by the repository's merge policy, including draft pull requests, updates, reopened pull requests, and pull requests from forks.

#### Scenario: Pull request reaches a gateable revision

- **WHEN** a pull request is opened, updated, reopened, or changes draft state
- **THEN** the repository publishes a `ci-gate` result for that pull request's current head revision

#### Scenario: Pull request head advances while validation is running

- **WHEN** a newer head revision replaces the revision being evaluated
- **THEN** the older evaluation cannot satisfy the gate for the newer revision

### Requirement: Applicability is determined by trusted policy

The `ci-gate` result SHALL determine applicable validations from policy owned by the default branch and the trusted changed-file set for the exact pull request revision. Candidate-controlled workflow conditions, path filters, labels, inputs, and generated status names SHALL NOT determine whether a required validation applies.

#### Scenario: Candidate changes a workflow condition

- **WHEN** a pull request changes a workflow condition that would suppress an applicable validation
- **THEN** the `ci-gate` result still evaluates applicability using the default-branch policy

#### Scenario: Candidate changes only non-applicable content

- **WHEN** the trusted changed-file set contains only content outside a validation's policy scope
- **THEN** that validation is reported as not applicable and does not block the pull request

### Requirement: Successful applicable validation is required

When a validation is applicable and macOS validation is enabled, `ci-gate` SHALL require a successful result for the current pull request head revision from the expected GitHub Actions workflow and job. Results from an earlier revision, another pull request, an unexpected check source, or an unrelated check with the same display name SHALL NOT satisfy the requirement.

#### Scenario: Applicable validation succeeds on the current revision

- **WHEN** every applicable validation reports success for the current pull request head revision
- **THEN** `ci-gate` reports success

#### Scenario: Applicable validation is missing or unsuccessful

- **WHEN** an applicable validation is missing, queued beyond the gate timeout, skipped, cancelled, timed out, neutral, or unsuccessful
- **THEN** `ci-gate` reports failure and identifies the validation that prevented success

### Requirement: Disabled macOS validation is an explicit opt-out

When the trusted repository variable `ENABLE_MACOSX_JOBS` is `false`, the repository SHALL NOT require or initiate pull-request macOS validation, and `ci-gate` SHALL report the disabled policy as an explicit non-error decision. The value SHALL be read from trusted repository configuration rather than pull-request content.

#### Scenario: Relevant pull request while macOS validation is disabled

- **WHEN** the changed-file policy would otherwise require macOS validation and `ENABLE_MACOSX_JOBS` is `false`
- **THEN** no macOS result is required for merge, `ci-gate` reports that macOS validation was disabled by repository policy, and the pull request may pass if all other applicable validations succeed

#### Scenario: Candidate attempts to enable or disable macOS validation

- **WHEN** a pull request changes workflow YAML, scripts, labels, inputs, or other candidate-controlled content related to `ENABLE_MACOSX_JOBS`
- **THEN** the candidate content does not change the value used by `ci-gate`

### Requirement: Expensive validation can short-circuit without passing

The repository SHALL avoid starting applicable macOS validation after a decisive required prerequisite has failed, while preserving a failing `ci-gate` result until the prerequisite is repaired and the applicable validation succeeds or the trusted macOS opt-out is active.

#### Scenario: Cheap prerequisite fails before macOS validation starts

- **WHEN** an applicable lightweight validation fails before macOS validation begins
- **THEN** the macOS work is not started for that revision and `ci-gate` remains unsuccessful

#### Scenario: Superseded run is cancelled

- **WHEN** a newer pull request revision supersedes an in-progress validation run
- **THEN** the older run is cancelled and cannot satisfy `ci-gate` for the newer revision

### Requirement: Gate diagnostics distinguish policy from validation

The `ci-gate` result SHALL identify each applicable validation as passed, failed, waiting, cancelled, skipped, timed out, not applicable, or disabled by trusted macOS policy. A disabled macOS validation SHALL NOT be represented as a successful test result.

#### Scenario: Reviewer inspects a passing gate with macOS disabled

- **WHEN** `ci-gate` succeeds while `ENABLE_MACOSX_JOBS` is `false`
- **THEN** the check summary shows that macOS validation was intentionally disabled and lists the remaining validations that passed

#### Scenario: Reviewer inspects a blocked gate

- **WHEN** `ci-gate` fails or waits for validation
- **THEN** the check summary names the missing or unsuccessful validation and identifies the current head revision being evaluated

### Requirement: Merge controls enforce the trusted gate

The protected default branch SHALL require the `ci-gate` result from the expected GitHub Actions integration, preserve code-owner review and thread-resolution requirements, dismiss stale approvals after new pushes, and require approval of the latest reviewable push. Individual conditional validation jobs SHALL NOT be the sole merge requirement.

#### Scenario: Required gate has not passed

- **WHEN** a pull request lacks a successful `ci-gate` result for its current revision
- **THEN** the protected default branch rejects the merge

#### Scenario: Agent pushes after approval

- **WHEN** a new commit is pushed after a human approval
- **THEN** the prior approval is not sufficient by itself and the latest revision must receive the required approval and a successful `ci-gate` result
