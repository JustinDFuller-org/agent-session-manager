## Purpose

Publish repository unit-test line coverage to GitHub so pull requests expose coverage changes against a default-branch baseline without covering dependencies or requiring a third-party service.

## ADDED Requirements

### Requirement: Repository unit coverage is generated for reviewable commits

When macOS CI jobs are enabled, the unit-test workflow MUST run the repository unit-test suite with coverage enabled for pull requests targeting the default branch and pushes to the default branch. The resulting report MUST include only repository source files and MUST exclude package checkouts, generated files, and build artifacts.

#### Scenario: Default-branch baseline coverage

- **WHEN** a commit is pushed to `main` and macOS CI jobs are enabled
- **THEN** the unit-test workflow produces a repository-only Cobertura coverage report for that commit

#### Scenario: Pull-request coverage

- **WHEN** a pull request targeting `main` runs with macOS CI jobs enabled
- **THEN** the unit-test workflow produces a repository-only Cobertura coverage report for the pull-request head commit

#### Scenario: Disabled macOS policy

- **WHEN** macOS CI jobs are disabled by repository policy
- **THEN** the coverage-producing job is skipped and the workflow does not claim that coverage was generated or uploaded

### Requirement: Coverage is published through GitHub Code Quality

After successful unit tests and report validation, the workflow MUST upload the Cobertura report to GitHub Code Quality with a stable coverage label. Default-branch reports MUST establish the comparison baseline and pull-request reports MUST be associated with the pull request head commit.

#### Scenario: Same-repository pull request upload

- **WHEN** a same-repository pull request completes its coverage-producing unit-test job successfully
- **THEN** GitHub Code Quality receives the report and can display the pull-request coverage comparison

#### Scenario: Default-branch upload

- **WHEN** a successful coverage-producing unit-test job runs for a push to `main`
- **THEN** GitHub Code Quality receives the report as the default-branch baseline

### Requirement: Coverage uploads do not grant write access to fork code

The workflow MUST run coverage tests for fork pull requests only under the permissions available to the pull-request event and MUST skip the Code Quality upload for fork pull requests. The workflow MUST grant no permissions beyond those required to read the repository and upload coverage for trusted same-repository events.

#### Scenario: Fork pull request

- **WHEN** a fork pull request runs the coverage workflow
- **THEN** tests may execute according to the existing macOS policy, but the coverage upload step is skipped without attempting a write using the fork's token

#### Scenario: Least-privilege permissions

- **WHEN** the coverage workflow is inspected
- **THEN** its permissions include repository read access and the specific Code Quality write permission required for upload, with pull-request read access only when needed for association

### Requirement: Invalid coverage output fails visibly

The coverage workflow MUST fail when the converter cannot produce a valid Cobertura report from the test output or when the coverage upload reports an error. It MUST NOT silently publish a missing, malformed, dependency-only, or stale report as successful coverage.

#### Scenario: Malformed source coverage

- **WHEN** the coverage input is malformed or cannot be converted into valid Cobertura XML
- **THEN** the conversion or validation step fails and the upload step does not report successful coverage

#### Scenario: Upload failure

- **WHEN** GitHub rejects the coverage upload or processing reaches a failed terminal state
- **THEN** the coverage step fails and the workflow exposes the failure in its result

### Requirement: Coverage publication does not enforce a threshold

The coverage workflow MUST publish measured coverage without failing solely because the percentage is below a configured minimum, and it MUST NOT change merge protection or required-check policy as part of this capability.

#### Scenario: Low measured coverage

- **WHEN** tests pass and the generated report contains a low line-coverage percentage
- **THEN** the report is still eligible for publication and no threshold failure is raised
