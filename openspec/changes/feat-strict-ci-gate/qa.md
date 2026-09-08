# QA evidence

The QA layer records local deterministic validation and read-only GitHub verification for `feat-strict-ci-gate`.

## Local validation

`node --test .github/scripts/*test.mjs` passed 86 tests with 0 failures, including evaluator policy states, exact provenance, pagination and truncation, event fixtures, workflow security structure, candidate isolation, and guidance consistency.

`openspec validate --all --strict` passed 6 items with 0 failures; the output contained only informational long-requirement notices.

`make no-code-comments`, `make no-fixed-width-prose`, `make lint`, and `make docs-check` all passed. The documentation check rendered 27 public pages and passed its internal link checks.

The Ruby YAML parser loaded every `.github/workflows/*.yml` file successfully, and `git diff --check` passed.

`actionlint` and `yamllint` were not available in the validation environment and were skipped. UI execution was not run locally because this QA layer does not alter the approved isolated `make test-ui-dev` invocation; the live pull-request macOS jobs were independently observed as skipped under the trusted repository policy below.

## Read-only GitHub verification

PR #357 (`feat-strict-ci-gate-integration`) was verified at head `3f31f2af92d314ab3267343ced24717d546ced78`, and PR #358 (`feat-strict-ci-gate-guidance`) was verified at head `f2f436dc259585de5b1302a99c2e83b860269121` after the checkout-permission correction was rebased into the guidance layer.

The refreshed PR #358 checks showed success for PR Description Check, WIP Check, no-code-comments, no-fixed-width-prose, Documentation, SwiftLint, and the trusted macOS policy-resolution jobs. The `swift test`, UI, and dependency/toolchain macOS jobs were skipped because the trusted repository variable `ENABLE_MACOSX_JOBS` was read as exactly `false`; this is an explicit disabled-policy state, not a test pass. The OpenSpec check was observed before formal stack metadata was linked and was not treated as final evidence until that link was completed.

The repository variable lookup was read-only and returned `ENABLE_MACOSX_JOBS=false`. The current main ruleset was also read-only inspected: it still requires the pre-migration individual contexts and does not contain `ci-gate`. The default-branch workflow listing likewise does not yet contain `ci-gate`, because the workflow is not live until its implementation layer reaches `main`.

The current ruleset therefore remains a manual owner-owned transition and this QA evidence makes no claim of live production `ci-gate` enforcement. The documented transition requires recording the complete existing ruleset, registering the GitHub Actions `ci-gate` context with strict status enforcement, preserving code-owner review, thread resolution, non-fast-forward protection, and human-only bypass, then re-reading and verifying the complete result. No repository administration settings were changed by QA.

The disposable verification used the real stacked pull requests and repository API state; no fabricated sessions, workflow results, candidate policy, or production application state were created.
