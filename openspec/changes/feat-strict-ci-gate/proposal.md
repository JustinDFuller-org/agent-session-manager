## Why

The repository currently has required checks that can report success without running, while other CI workflows are not required at all. Pull-request-owned workflow files can also change the commands and conditions that define their own checks, and expensive macOS jobs are globally disabled or needlessly started without a trusted applicability decision. The repository needs a base-owned merge gate that preserves strict enforcement where validation is enabled while making deliberate cost-saving exceptions visible and safe.

## What Changes

- Add a base-owned `ci-gate` merge check that evaluates the exact pull request head SHA and publishes one stable required result.
- Classify applicable validations from trusted default-branch policy instead of trusting pull-request workflow conditions, path filters, or candidate-controlled inputs.
- Keep lightweight Ubuntu validations available for pull requests and run macOS unit, UI, and compatibility validation only for relevant source, test, package, build, app-resource, or enforcement changes.
- Treat `ENABLE_MACOSX_JOBS=false` as an explicit maintainer-controlled opt-out: applicable macOS validation is not run, the gate reports the policy decision, and the pull request may pass.
- Treat missing, skipped, cancelled, stale, timed-out, or failed validations as gate failures whenever the trusted policy says the validation applies and macOS validation is enabled.
- Preserve concurrency cancellation and short-circuit expensive macOS work after decisive prerequisite failures without converting the resulting gate state into success.
- Document the required external GitHub ruleset and review configuration: require only `ci-gate`, preserve code-owner review, dismiss stale approvals, and require approval of the latest reviewable push.
- **BREAKING** Replace the current collection of individually required job contexts with the single aggregate `ci-gate` context.

## Capabilities

### New Capabilities

- `strict-ci-gate`: Defines trusted CI applicability, exact-SHA aggregation, macOS cost controls, and merge-gate outcomes for pull requests.

### Modified Capabilities

None.

## Impact

- GitHub Actions workflows and scripts under `.github/workflows/` and `.github/scripts/` will gain a base-owned policy and aggregate-gate implementation without executing candidate workflow code from the privileged event.
- Existing Ubuntu and macOS workflow triggers, conditions, concurrency groups, and check names will be reorganized around the aggregate result.
- Repository ruleset configuration must be updated manually because workflow files cannot configure required checks, review settings, or bypass actors.
- CI tests, workflow validation, OpenSpec guidance, and pull-request review instructions will be updated; no application runtime APIs or user data formats change.

## Deliberately Out of Scope

- Replacing GitHub Actions, changing the repository owner or authentication model, or moving CI to another provider.
- Treating a passing test as proof that candidate production code is semantically correct when the candidate is allowed to change the code under test.
- Automatically changing repository variables, rulesets, review settings, or bypass permissions from CI.
- Changing release, scheduled maintenance, Dependabot automation, screenshot capture, or post-merge publication workflows except where they must be excluded from pull-request gate accounting.
