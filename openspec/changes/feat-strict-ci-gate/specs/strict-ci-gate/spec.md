## Purpose

Provides a single native GitHub Actions merge result for every pull request while making macOS cost controls explicit and preserving strict validation for applicable changes.

## ADDED Requirements

### Requirement: Pull requests have one authoritative CI gate

The repository SHALL run one pull-request orchestration workflow for every gateable pull request revision whose stack trunk is `main`, and that workflow SHALL publish a final `ci-gate` job result for the current head revision. The workflow SHALL react to opened, edited, synchronized, reopened, ready-for-review, and converted-to-draft pull-request events.

#### Scenario: A pull request revision is gateable

- **WHEN** a pull request targeting the stack trunk is opened, updated, reopened, changes draft state, or has metadata edited
- **THEN** the orchestration workflow runs its preflight, applicable validations, and final `ci-gate` job for that revision

#### Scenario: A newer revision replaces an older run

- **WHEN** a newer pull-request revision is pushed while the previous orchestration is running
- **THEN** the previous run is cancelled by the pull-request concurrency group and cannot provide the final result for the newer revision

### Requirement: Validation workflows are reusable and retain non-PR entry points

Each required validation SHALL be implemented by a local reusable workflow with a `workflow_call` entry point. Existing push, schedule, and manual entry points that are not pull-request merge accounting SHALL remain available where applicable. The caller SHALL invoke each validation as a separate job.

#### Scenario: Caller invokes a lightweight validation

- **WHEN** the pull-request caller starts
- **THEN** it invokes the corresponding local reusable workflow as a job with the repository's least-privilege permissions

#### Scenario: A non-PR validation is requested

- **WHEN** a preserved push, scheduled, or manual trigger fires
- **THEN** its reusable workflow runs without requiring the pull-request caller

### Requirement: MacOS applicability is selected by a tested Git preflight

The repository SHALL compare the trusted stack-base revision with the pull-request head revision and emit exactly one macOS mode: `required`, `disabled-policy`, or `not-applicable`. Documentation-only changes SHALL select `not-applicable`; relevant classified changes SHALL select `required`; exact repository variable value `ENABLE_MACOSX_JOBS=false` SHALL select `disabled-policy`. Unknown paths, invalid revisions, incomplete diffs, missing variables, and malformed variable values SHALL fail closed to `required` or fail the preflight job.

#### Scenario: Documentation-only change

- **WHEN** every changed path is in the documented documentation-only allowlist
- **THEN** the preflight emits `macos_mode=not-applicable`

#### Scenario: Relevant source change with enabled policy

- **WHEN** a changed path is source, test, package, project, build, resource, toolchain, or enforcement content and the repository variable is not exactly `false`
- **THEN** the preflight emits `macos_mode=required`

#### Scenario: Exact disabled policy

- **WHEN** the relevant changed-file set is non-documentation content and `ENABLE_MACOSX_JOBS` is exactly `false`
- **THEN** the preflight emits `macos_mode=disabled-policy`

#### Scenario: Input cannot be trusted

- **WHEN** a revision is invalid, the diff cannot be completed, a path is unknown, or the repository variable is missing or malformed
- **THEN** the preflight fails closed and does not emit a passing or not-applicable decision

### Requirement: Prerequisites short-circuit expensive validation

The macOS caller jobs SHALL depend on the preflight and every lightweight validation. A macOS caller SHALL run only when preflight emits `required` and all lightweight prerequisites succeed. A failed prerequisite SHALL leave the final `ci-gate` unsuccessful and SHALL NOT be treated as macOS success or non-applicability.

#### Scenario: Lightweight validation fails

- **WHEN** a lightweight caller fails for the current revision
- **THEN** applicable macOS callers are skipped and `ci-gate` identifies the prerequisite failure

#### Scenario: All prerequisites pass

- **WHEN** preflight emits `required` and every lightweight caller succeeds
- **THEN** each applicable macOS caller starts for the current revision

### Requirement: The final gate aggregates native job results

The final `ci-gate` job SHALL depend on the preflight, every lightweight caller, and every macOS caller and SHALL execute with an unconditional `always()` condition. It SHALL pass only when every lightweight caller succeeds and every macOS caller succeeds when required. It SHALL accept skipped macOS callers only when preflight explicitly emitted `disabled-policy` or `not-applicable`; all other failed, cancelled, skipped, or unexpectedly absent required jobs SHALL fail the gate.

#### Scenario: All required callers succeed

- **WHEN** preflight and every applicable caller succeed
- **THEN** `ci-gate` succeeds

#### Scenario: MacOS is intentionally skipped

- **WHEN** preflight emits `disabled-policy` or `not-applicable` and all lightweight callers succeed
- **THEN** macOS callers may be skipped and `ci-gate` succeeds while its summary identifies the explicit policy reason

#### Scenario: Required caller is unsuccessful

- **WHEN** any required caller fails, is cancelled, or is skipped unexpectedly
- **THEN** `ci-gate` fails and identifies that caller and its native job result

### Requirement: Best-effort automation is not merge accounting

OpenSpec guide comments and label application SHALL remain separate best-effort automation and SHALL NOT be dependencies of `ci-gate`. The repository SHALL NOT use a title-based WIP action as a required validation.

#### Scenario: Best-effort automation is unavailable

- **WHEN** the guide comment or label automation is skipped or unavailable
- **THEN** the required caller graph and `ci-gate` remain defined without treating that automation as a merge validation

### Requirement: Required workflow security boundaries remain explicit

The orchestration and reusable validation workflows SHALL use empty default permissions, grant only job-level permissions required by the validation, pin third-party actions to full commit SHAs, disable checkout credentials, and avoid candidate code in privileged best-effort jobs. The required gate SHALL execute only native job-result logic and SHALL not poll GitHub APIs or load a candidate-controlled policy.

#### Scenario: Workflow contract is inspected

- **WHEN** the repository workflow contract tests inspect the caller and reusable workflows
- **THEN** they verify the caller dependencies, `always()` gate, skip policy, empty defaults, least privilege, action pins, and separation of best-effort jobs
