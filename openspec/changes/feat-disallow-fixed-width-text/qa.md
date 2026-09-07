# QA evidence

This validation layer records integrated acceptance evidence for the fixed-width prose policy and does not archive the OpenSpec change.

## Automated checks

- `node --test .github/scripts/*.test.mjs` passed with 50 tests.
- `make no-fixed-width-prose` passed with `fixed-width-prose: no violations found`.
- `openspec validate --all --strict` passed with 4 artifacts and 0 failures.
- The Ruby Psych workflow parser accepted all 15 workflow files.
- `make docs-check` passed taxonomy validation for 27 public pages, the Jekyll build, HTML-Proofer, and internal link and hash checks.
- `scripts/test-release-publishing.sh` passed the release publication contract.
- `make lint` passed strict Swift formatting for `Sources/`, `Tests/`, and `UITests/`.
- `swift test` passed 1,126 XCTest cases and 123 Swift Testing cases with 0 failures; the compiler emitted existing warnings only.
- `skills-ref validate` passed for all 62 top-level agent skills.
- `git diff --check` passed.

## Disposable candidate checks

- A temporary tracked Markdown file with a wrapped paragraph failed validation with a file and line diagnostic.
- The cleaned temporary Markdown file passed validation.
- A temporary pull-request description with a wrapped paragraph failed validation with a pull-request-description diagnostic.
- The cleaned temporary pull-request description passed validation.
- A wrapped commit body returned no blocking findings because commit bodies receive guidance only.
- A structural fixture containing fenced code, indented code, tables, front matter, a heading, raw HTML, and separate one-line list items returned no findings.
- The temporary candidate and all fixture files were removed after the checks.

## Applicability and verification

- UI tests were not run because this layer changes repository policy, documentation, and validation tooling without changing application runtime or UI behavior.
- The OpenSpec implementation review maps every requirement and scenario to the validator, CI workflow, guidance, migration, regression tests, and the evidence above.
- All 13 implementation tasks are checked off, no critical verification issues were found, and the change remains unarchived for the later final archive layer.
