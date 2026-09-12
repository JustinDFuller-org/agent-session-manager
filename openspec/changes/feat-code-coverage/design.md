## Context

The existing `unit-tests.yml` workflow already runs `swift test --enable-code-coverage` on `macos-15`, but it is triggered only by pull requests and manual dispatch and stops before exporting or uploading coverage. SwiftPM produces coverage JSON and LLVM profile data that include package dependencies, while GitHub Code Quality accepts Cobertura XML through `actions/upload-code-coverage@v1`. The existing `ENABLE_MACOSX_JOBS` variable must remain the policy gate for macOS work.

## Goals / Non-Goals

**Goals:**

- Reuse the existing unit-test execution so coverage does not require a second macOS test run.
- Publish source-filtered coverage for both `main` baselines and pull-request comparisons.
- Keep conversion deterministic, dependency-free, locally testable, and explicit about malformed input.
- Preserve fork safety and distinguish disabled macOS policy from successful coverage.

**Non-Goals:**

- Adding UI-test or screenshot coverage.
- Adding a third-party coverage service or package dependency.
- Enforcing a coverage threshold or modifying branch protection.

## Decisions

### Extend the existing unit-test workflow

The coverage pipeline will be added to `.github/workflows/unit-tests.yml` instead of creating a second workflow that repeats the approximately one-minute unit-test run. The workflow will retain `workflow_dispatch` for diagnostics, add `push` on `main` for the baseline, and continue to gate the job on `ENABLE_MACOSX_JOBS == 'true'`. Coverage upload will be limited to pull-request and `main` push events.

### Measure the pull-request head commit

Checkout will explicitly use `${{ github.event.pull_request.head.sha || github.sha }}` so source paths and line numbers in the report correspond to the reviewed commit rather than the synthetic pull-request merge commit. This follows GitHub Code Quality's coverage guidance and keeps baseline uploads on the pushed commit SHA.

### Export with LLVM and convert with a standard-library utility

After `swift test --enable-code-coverage`, the workflow will locate the generated test executable and run `llvm-cov export --format=lcov` with the repository source directories as filters. A new Python standard-library utility will parse LCOV records, allow only `Sources/AgentSessionManager` and `Sources/AgentSessionManagerMCPBridgeCore`, normalize paths to the checkout, and emit Cobertura XML with per-file line counts and aggregate line-rate metadata. It will reject malformed records, missing source files, paths outside the allowlist, and empty reports.

This avoids a third-party converter dependency. Directly consuming SwiftPM's JSON would retain LLVM-specific segment details that are unnecessary for GitHub's line-oriented Cobertura input, while replacing the existing SwiftPM test path with Xcode result-bundle coverage would add an unrelated UI/build-system migration.

### Validate before upload and fail on upload errors

The converter test suite will cover valid records, uncovered lines, multiple files, path filtering, XML escaping, malformed input, and empty output. The workflow will validate the generated XML before upload. The upload action will use the repository's required Code Quality permission and its default failure behavior so missing or rejected coverage remains visible.

### Protect fork pull requests

The upload step will use the same-repository condition recommended by GitHub: uploads are allowed for non-PR events or pull requests whose head repository equals the current repository. Fork pull requests may run tests but will not attempt a Code Quality write. The workflow will use only read permissions plus `code-quality: write` and pull-request read access needed by the upload action.

## Risks / Trade-offs

- [Risk] LLVM coverage output paths or test-binary locations vary between Swift toolchains → [Mitigation] derive paths from SwiftPM's reported build output, use explicit source-root filters, and test the workflow's structural assumptions locally.
- [Risk] The standard-library converter becomes a maintenance point → [Mitigation] keep its input/output contract small, add fixture-based tests, validate the final XML, and avoid supporting formats beyond the LCOV records emitted by this workflow.
- [Risk] macOS CI policy or GitHub Code Quality availability prevents an upload → [Mitigation] preserve the existing policy gate, expose skipped/failed states honestly, and document Code Quality enablement as a repository prerequisite.
- [Risk] Dependency source paths accidentally inflate reported coverage → [Mitigation] enforce the two repository source-root allowlists in both conversion logic and tests.
