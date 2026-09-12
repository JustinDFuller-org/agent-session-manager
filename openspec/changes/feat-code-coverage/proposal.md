## Why

The repository already measures Swift unit-test coverage in CI, but it does not publish that data to pull requests or establish a default-branch baseline. Adding first-party GitHub Code Quality coverage reporting will make untested changes visible during review without introducing a hosted third-party coverage service.

## What Changes

- Extend the existing macOS unit-test workflow to generate a filtered Cobertura XML report from SwiftPM and LLVM coverage output.
- Run the coverage-producing unit-test workflow on pull requests and pushes to `main`, while preserving the existing macOS-job policy gate.
- Upload same-repository pull-request and default-branch coverage reports through GitHub's `actions/upload-code-coverage` action with least-privilege permissions.
- Add a dependency-free, tested LCOV-to-Cobertura conversion utility and workflow validation for report paths, source filtering, permissions, event handling, and fork safety.
- Do not enforce a minimum coverage threshold in this change.

## Capabilities

### New Capabilities

- `code-coverage`: Publish repository unit-test line coverage to GitHub Code Quality for default-branch baselines and pull-request comparisons.

### Modified Capabilities

None.

## Impact

The implementation will affect the unit-test GitHub Actions workflow, add a small coverage-report conversion and test utility, and add local/CI validation for the generated Cobertura document. It will use the existing SwiftPM test target and macOS runner; it will not change application APIs, production runtime behavior, UI tests, or package dependencies.

## Deliberately Out of Scope

- UI-test or screenshot coverage.
- Codecov, Coveralls, or another third-party coverage service.
- Coverage thresholds, merge blocking, or quality-gate policy changes.
- Coverage for Swift package dependencies or generated/build files.
