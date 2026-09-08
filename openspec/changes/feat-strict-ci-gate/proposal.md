## Why

The repository currently has required checks that can report success without running, while other CI workflows are not required at all. Pull-request-owned workflow files can also change the commands and conditions that define their own checks, and expensive macOS jobs are globally disabled or needlessly started without a trusted applicability decision. The repository needs a base-owned merge gate that preserves strict enforcement where validation is enabled while making deliberate cost-saving exceptions visible and safe.

## What Changes

- Add a base-owned `ci-gate` merge check that evaluates the exact pull request head SHA and publishes one stable required result.
- Define a versioned, base-owned validation matrix that names every pull-request validation, its canonical workflow/job identity, its applicability categories, its trigger expectations, and its prerequisite relationships.
- Classify applicability from that policy and a complete trusted changed-file manifest. Candidate-controlled workflow conditions, path filters, labels, inputs, and generated status names cannot decide whether a required validation applies.
- Keep lightweight Ubuntu validations available for pull requests and run macOS unit, UI, and compatibility validation only for relevant source, test, package, build, app-resource, toolchain, or enforcement changes identified by the policy. Unclassified paths fail closed into applicability.
- Treat `ENABLE_MACOSX_JOBS=false` as an explicit maintainer-controlled opt-out: applicable macOS validation is not initiated or required, the gate reports the policy decision, and the pull request may pass only when all other applicable validations succeed.
- Treat missing, skipped, cancelled, stale, timed-out, neutral, or failed validations as gate failures whenever the trusted policy says the validation applies and macOS validation is enabled.
- Preserve concurrency cancellation and short-circuit expensive macOS work after decisive prerequisite failures without converting the resulting gate state into success.
- Require the protected default branch to use the `ci-gate` result from the expected GitHub Actions integration while preserving strict status enforcement, code-owner review, and thread resolution.
- Keep stale-review dismissal and latest-push approval as a separately controlled review-policy decision. Do not enable either setting as part of the gate migration until the repository's stacked-merge procedure has been verified to satisfy it.
- **BREAKING** Replace the current collection of individually required job contexts with the single aggregate `ci-gate` context after the new workflow and its validation matrix are available.

## Capabilities

### New Capabilities

- `strict-ci-gate`: Defines trusted CI applicability, exact-SHA aggregation, macOS cost controls, provenance checks, diagnostics, and merge-gate outcomes for pull requests.

### Modified Capabilities

None.

## Impact

- GitHub Actions workflows and scripts under `.github/workflows/` and `.github/scripts/` will gain a base-owned policy and aggregate-gate implementation without executing candidate workflow code from the privileged event.
- Existing Ubuntu and macOS pull-request workflow triggers, conditions, concurrency groups, and check identities will be reorganized around the aggregate result, while release, scheduled, manual-only, and Dependabot automation remain outside pull-request gate accounting.
- The policy evaluator will use the GitHub API with bounded pagination and an explicit changed-file ceiling; an incomplete manifest, unknown result provenance, or policy inconsistency will fail closed.
- Repository ruleset configuration must be updated manually because workflow files cannot configure required checks, review settings, or bypass actors. The target ruleset migration and its current review settings will be documented separately from implementation.
- CI tests, workflow validation, OpenSpec guidance, and pull-request review instructions will be updated; no application runtime APIs or user data formats change.

## Deliberately Out of Scope

- Replacing GitHub Actions, changing the repository owner or authentication model, or moving CI to another provider.
- Treating a passing test as proof that candidate production code is semantically correct when the candidate is allowed to change the code under test.
- Automatically changing repository variables, rulesets, review settings, or bypass permissions from CI.
- Changing release, scheduled maintenance, Dependabot automation, screenshot capture, or post-merge publication workflows except where they must be excluded from pull-request gate accounting.
- Enabling latest-push approval or stale-review dismissal without first verifying a stack-compatible merge procedure and obtaining the required repository-owner approval for that external policy change.
