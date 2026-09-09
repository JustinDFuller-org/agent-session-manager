# QA evidence

This file records the native caller, reusable-workflow, preflight, and gate validation for `feat-strict-ci-gate`.

## Local validation

The preflight and workflow-contract suites passed 18 tests with 0 failures, and the complete `.github/scripts/*test.mjs` suite passed 71 tests with 0 failures. `openspec validate --all --strict`, `make no-code-comments`, `make no-fixed-width-prose`, `make lint`, `swiftlint lint --strict --config .swiftlint.yml`, `make docs-check`, Ruby YAML parsing for every workflow, and `git diff --check` passed. Swift validation passed 1,126 XCTest cases and 123 Swift Testing cases with 0 failures. `actionlint` and `yamllint` were unavailable and skipped.

`make xcodeproj` passed. The approved `make test-ui-dev` command and `make screenshots` both reached Xcode but failed before UI tests or screenshot capture while validating the existing `SwiftTermBuildInfoPlugin` (`xcodebuild` Error 65); these are recorded as infrastructure/build-plugin failures, not passing UI or screenshot results.

## Read-only GitHub verification

The current repository variable readback is `ENABLE_MACOSX_JOBS=false`, so relevant macOS validation must be reported as `disabled-policy` and documentation-only changes as `not-applicable`; neither is a test pass. The final evidence will identify each retained stack layer, its current head, the native `ci-gate` result, and the complete ruleset readback. It will not claim live production enforcement until the external ruleset migration is complete.

Formal stack submission created stack #365 with PRs #353, #364, #358, #359, and #361; their immediate bases are `main`, `feat-consistent-action-runs`, `feat-strict-ci-gate-native`, and `feat-strict-ci-gate-guidance`, respectively, and superseded PRs #354, #356, and #357 were closed after verification. Submitted-head GitHub results are recorded separately as passed, skipped by policy, and failed base-owned OpenSpec/bootstrap checks; the top native `CI` run was observed in progress before this evidence snapshot.

The live `main` ruleset readback remains `active` with strict required status checks for `openspec-guide`, `openspec-label`, `PR Description Check`, `WIP Check`, `swift test`, `no-code-comments`, `openspec-check`, and `no-fixed-width-prose`, all GitHub Actions integration `15368`; it also retains one approving review, code-owner review, resolved threads, squash-only merges, deletion protection, and non-fast-forward protection. Replacing those contexts with `ci-gate` is not recorded as complete because explicit owner approval for that external ruleset mutation was not supplied.
