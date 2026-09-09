# QA evidence

This file records the native caller, reusable-workflow, preflight, and gate validation for `feat-strict-ci-gate`.

## Local validation

The preflight and workflow-contract suites passed 18 tests with 0 failures, and the complete `.github/scripts/*test.mjs` suite passed 71 tests with 0 failures. `openspec validate --all --strict`, `make no-code-comments`, `make no-fixed-width-prose`, `make lint`, `swiftlint lint --strict --config .swiftlint.yml`, `make docs-check`, Ruby YAML parsing for every workflow, and `git diff --check` passed. Swift validation passed 1,126 XCTest cases and 123 Swift Testing cases with 0 failures. `actionlint` and `yamllint` were unavailable and skipped.

`make xcodeproj` passed. The approved `make test-ui-dev` command reached Xcode but failed before UI tests while validating the existing `SwiftTermBuildInfoPlugin` (`xcodebuild` Error 65); this is recorded as an infrastructure/build-plugin failure, not a passing UI result. Screenshots remain pending the same isolated UI build path.

## Read-only GitHub verification

The current repository variable readback is `ENABLE_MACOSX_JOBS=false`, so relevant macOS validation must be reported as `disabled-policy` and documentation-only changes as `not-applicable`; neither is a test pass. The final evidence will identify each retained stack layer, its current head, the native `ci-gate` result, and the complete ruleset readback. It will not claim live production enforcement until the external ruleset migration is complete.
