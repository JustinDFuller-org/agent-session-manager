## 1. Coverage Report Conversion

- [ ] 1.1 Add a dependency-free LCOV-to-Cobertura utility that normalizes checkout-relative paths, accepts only the two repository source roots, calculates per-file and aggregate line rates, escapes XML values, and rejects malformed, empty, missing-source, or out-of-scope input; verify it with a focused executable test command.
- [ ] 1.2 Add converter fixtures and tests for covered and uncovered lines, multiple files, dependency/path exclusion, XML escaping, malformed records, missing files, and empty reports; verify the complete converter test suite passes.

## 2. GitHub Actions Integration

- [ ] 2.1 Update the existing unit-test workflow to run on `main` pushes and default-branch pull requests, check out the reviewed commit, preserve the `ENABLE_MACOSX_JOBS` gate, and grant only the permissions required for coverage publication; verify the workflow parses and structural assertions cover triggers, checkout, permissions, and conditions.
- [ ] 2.2 Add workflow steps that locate the SwiftPM test executable, export filtered LLVM LCOV data, convert and validate Cobertura XML, and upload it with a stable GitHub Code Quality label; verify a local coverage run produces XML containing repository sources but no dependency or build paths.
- [ ] 2.3 Guard uploads for fork pull requests and non-baseline manual dispatches while preserving test execution behavior; verify the workflow skips unsafe uploads and does not present disabled macOS policy as successful coverage.

## 3. End-to-End Validation

- [ ] 3.1 Run the unit-test suite with coverage enabled and confirm the generated Cobertura report is accepted by the converter and XML validation checks; record any toolchain-specific path assumptions in the implementation change.
- [ ] 3.2 Run `make no-code-comments`, `make no-fixed-width-prose`, strict OpenSpec validation, the workflow/converter tests, and `git diff --check`; verify all relevant checks pass without modifying application code.
