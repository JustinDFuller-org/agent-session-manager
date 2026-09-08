# OpenSpec in this repo

This repo uses [OpenSpec](https://openspec.dev)'s `opsx` workflow. OpenSpec keeps the agreed requirements, design decisions, and implementation tasks in the repository so a human can review the contract before implementation is merged.

## Every pull request needs OpenSpec

Every pull request requires a valid OpenSpec change, including drafts and pull requests that change only code, documentation, automation, dependencies, or repository metadata. The `openspec-check` status is strict on every pull request and every layer of a formal GitHub stacked pull request. A draft does not relax the gate.

Continuation layers may retain the shared active change and unchecked tasks while implementation or QA proceeds. The current top layer of a stack, and every standalone pull request, is the finalization layer. It must contain:

- the repository's spec-driven artifacts (`.openspec.yaml`, `proposal.md`, `design.md`, `tasks.md`, and a delta specification);
- a corresponding main specification under `openspec/specs/`;
- no `skip_specs` shortcut;
- every task checked; and
- no active change remaining under `openspec/changes/`.

The finalization layer must archive the exact shared change set in an archive-only pull request. Existing archived changes on the stack trunk do not count as a new change, and higher layers must preserve the change names handed off by their immediate base.

The gate runs the pinned OpenSpec CLI with strict validation and archived-change validation. Its production workflow is base-owned on `main`, and it evaluates the immutable candidate revision for the pull request rather than scripts or workflows supplied by that candidate.

## The command sequence

1. `/opsx:explore` — work out the requirements and open questions with the agent
2. `/opsx:propose` — write `proposal.md`, `specs/<capability>/spec.md`, `design.md`, and `tasks.md` for review; **no implementation yet**
3. Iterate on the spec with your reviewer(s) until it is locked in
4. `/opsx:apply` — implement `tasks.md`
5. PR review — human and AI feedback on the implementation and the spec
6. Run QA in its own continuation pull request when the stack has a separate QA layer; record the commands, results, and evidence links in that PR's description.
7. Create the final archive pull request at the current top of the stack. It must contain only the archive transition and synchronized main specifications.
8. `/opsx:archive` — archive the change as the last OpenSpec step, after review feedback is resolved and before the archive pull request is marked ready for review
9. Merge

### Stacked pull requests

For a formal stack rooted at `main`, the change follows this lifecycle:

`OpenSpec -> implementation 1..n -> QA -> archive`

#### Use the `gh stack` CLI

Use the [canonical stacked-PR skill](../.agents/skills/openspec-stacked-prs/SKILL.md) for the complete command procedure. The short form is:

1. Create a new stack with `gh stack init`, `gh stack add`, and `gh stack submit`, or formally link existing PRs with `gh stack link <bottom-pr> <next-pr> ...` in bottom-to-top order.
2. Import the remote stack with `gh stack checkout <top-pr>`.
3. Verify formal metadata with `gh stack view --json` and verify every PR's immediate-parent base with `gh pr view`.

`gh pr create --base` establishes a branch dependency but does not prove formal stack membership. One implementation PR contains one complete top-level task group and all of its subtasks. `gh stack sync`, `gh stack push`, and `gh stack rebase` may use `--force-with-lease` only for a stack feature branch after verifying the current remote head, immediate-parent base, branch ownership, and branch protection; `--force-with-lease` is still a force-push operation. Never force-update `main` or another protected branch. See GitHub's [stacked pull request overview](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs), [quickstart](https://docs.github.com/en/pull-requests/get-started/stacked-prs-quickstart), and [CLI reference](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands).

The archive pull request is always the current top layer. Lower layers must carry the exact active change set from their immediate base, may leave tasks unchecked, and must not archive or introduce a competing change. The top layer must complete the tasks, archive the shared changes, synchronize the matching main specifications, and contain no implementation, QA, or unrelated files in its direct diff.

The intended decomposition is the OpenSpec proposal, one or more implementation layers, a QA layer, and an archive layer. Each implementation layer owns one complete top-level task group with all of its subtasks, and keeping QA separate from the archive layer preserves the archive-only final diff. This is guidance rather than a CI minimum; standalone and shorter stacks are supported. A standalone pull request is treated as a one-layer stack and must perform the final archive step itself.

When lower pull requests merge, GitHub reduces the remaining stack's position and size. The pull request that is then `position == size` remains the archive owner. The stack trunk may temporarily contain the active change during this collapse; the immediate base preserves the shared identity and permits the active-to-archived handoff. Do not use the original stack length or pull request number to choose the archive owner.

When the QA work is the last non-archive layer, record its exact validation steps, expected and observed results, useful CI links, and any disposable fixture cleanup in that QA pull request's description. Then create the separate archive pull request and resolve its review feedback before marking it ready.

## Install OpenSpec

Install the repository's pinned OpenSpec CLI version:

```bash
npm install -g @fission-ai/openspec@1.10.0
```

The `/opsx:*` commands are OpenSpec workflows that run inside a supported AI coding assistant. Follow the [official OpenSpec setup guide](https://openspec.dev/docs/getting-started) to install the integration for your assistant. The `openspec` CLI must be on `PATH` before a workflow starts.

### Preserve the repository configuration

This repository has a curated `openspec/config.yaml`. Review the working-tree diff after running `openspec init` or `openspec update`, and do not overwrite that file with profile-generated defaults.

## What a reviewer should read

Read `specs/<capability>/spec.md`. It is the requirement contract, written to stand on its own. The other planning artifacts (`proposal.md`, `design.md`, `tasks.md`, `.openspec.yaml`) are working material for the agent and a historical record; they remain visible to automated code review and are not out of scope for findings.

## If you disagree with a requirement

Stop reviewing the parts of the implementation affected by that requirement until the disagreement is resolved. Reviewing an implementation against a requirement you do not agree with wastes both sides' time.

## Archiving is the last OpenSpec step

A change is archived only after review feedback on the change has been resolved, immediately before the pull request is marked ready for review. The archive is required even when the pull request is a draft; keeping a draft only allows the work to remain under review while the strict check explains what is still missing.

Tasks must describe work that can be completed and verified before archiving. Verifying, archiving, marking the pull request ready, and merging are the workflow itself, not tasks. Work that can only happen after merge belongs under a `## Follow-ups after merge` heading in `proposal.md`, with a tracking issue when it needs an owner.

## Strict CI gate reference

The base-owned `ci-gate` workflow is the authoritative pull-request merge result. It reads the policy and evaluator from the default branch, reads the complete changed-file manifest and GitHub Actions evidence through the API, and evaluates the exact pull-request head SHA. It does not check out or execute candidate workflow files, scripts, package manifests, tests, or build commands.

The policy matrix is the source of truth for applicability and provenance:

| Policy ID | Check | Applicability | Workflow file | Event | Job | Prerequisites | macOS |
|---|---|---|---|---|---|---|---|
| `pr-description` | `PR Description Check` | `every` | `.github/workflows/pr-quality.yml` | `pull_request` | `PR Quality` / `PR Description Check` | `none` | `not used` |
| `wip-check` | `WIP Check` | `every` | `.github/workflows/pr-quality.yml` | `pull_request` | `PR Quality` / `WIP Check` | `none` | `not used` |
| `openspec-guide` | `openspec-guide` | `same-repository` | `.github/workflows/openspec-guide.yml` | `pull_request_target` | `OpenSpec Guide` / `openspec-guide` | `none` | `not used` |
| `openspec-check` | `openspec-check` | `every` | `.github/workflows/openspec.yml` | `pull_request_target` | `OpenSpec` / `openspec-check` | `none` | `not used` |
| `openspec-label` | `openspec-label` | `same-repository` | `.github/workflows/openspec.yml` | `pull_request_target` | `OpenSpec` / `openspec-label` | `none` | `not used` |
| `no-code-comments` | `no-code-comments` | `every` | `.github/workflows/no-code-comments.yml` | `pull_request_target` | `No Code Comments` / `no-code-comments` | `none` | `not used` |
| `no-fixed-width-prose` | `no-fixed-width-prose` | `every` | `.github/workflows/no-fixed-width-prose.yml` | `pull_request_target` | `Fixed-width Prose` / `no-fixed-width-prose` | `none` | `not used` |
| `swift-format` | `swift-format check` | `every` | `.github/workflows/format.yml` | `pull_request` | `Format` / `swift-format check` | `none` | `not used` |
| `swiftlint` | `SwiftLint` | `every` | `.github/workflows/lint.yml` | `pull_request` | `Lint` / `SwiftLint` | `none` | `not used` |
| `docs-check` | `Jekyll build and link check` | `every` | `.github/workflows/docs.yml` | `pull_request` | `Documentation` / `Jekyll build and link check` | `none` | `not used` |
| `resolve` | `swift package resolve` | `every` | `.github/workflows/swift-build-check.yml` | `pull_request` | `Swift Build Check` / `swift package resolve` | `none` | `not used` |
| `unit-tests` | `swift test` | `changed-categories: source, tests, ui-tests, package, project, build, resources, toolchain, enforcement; macOS variable enabled` | `.github/workflows/unit-tests.yml` | `pull_request` | `Unit Tests` / `swift test` | `swift-format`, `swiftlint`, `docs-check`, `resolve` | `true` |
| `ui-tests` | `make test-ui-dev-launch` | `changed-categories: source, tests, ui-tests, package, project, build, resources, toolchain, enforcement; macOS variable enabled` | `.github/workflows/ui-tests.yml` | `pull_request` | `UI Tests` / `make test-ui-dev-launch` | `swift-format`, `swiftlint`, `docs-check`, `resolve` | `true` |
| `compatibility` | `Dependency and toolchain compatibility` | `changed-categories: source, tests, ui-tests, package, project, build, resources, toolchain, enforcement; macOS variable enabled` | `.github/workflows/dependency-toolchain-compatibility.yml` | `pull_request` | `Dependency and Toolchain Compatibility` / `Dependency and toolchain compatibility` | `swift-format`, `swiftlint`, `docs-check`, `resolve` | `true` |

Every matrix row expects the pull-request types `opened`, `edited`, `synchronize`, `reopened`, `ready_for_review`, and `converted_to_draft`.

For `changed-categories`, the trusted categories are `source`, `tests`, `ui-tests`, `package`, `project`, `build`, `resources`, `toolchain`, and `enforcement`; the policy also defines `documentation` for the explicit macOS allowlist. The exact patterns are defined in `.github/ci-gate-policy.json`; new or unknown paths are not silently treated as documentation.

| Category | Exact patterns |
|---|---|
| `documentation` | `documentation/**`, `README.md`, `USER_FACING_DOCS.md`, `AGENTS.md`, `CLAUDE.md`, `AGENTIC_CONTROL.md`, `OPENCODE_SUPPORT.md`, `PROGRESS.md` |
| `resources` | `Sources/**/Resources/**`, `Assets.xcassets/**` |
| `source` | `Sources/**` |
| `tests` | `Tests/**` |
| `ui-tests` | `UITests/**` |
| `package` | `Package.swift`, `Package.resolved` |
| `project` | `project.yml`, `*.xcodeproj/**`, `*.xcworkspace/**` |
| `build` | `Makefile`, `scripts/**`, `*.xcconfig`, `*.plist` |
| `toolchain` | `.swift-version`, `.xcode-version` |
| `enforcement` | `.github/**`, `.agents/**`, `openspec/**` |

| macOS non-applicable allowlist | Exact patterns |
|---|---|
| `documentation-only` | `documentation/**`, `README.md`, `USER_FACING_DOCS.md`, `AGENTS.md`, `CLAUDE.md`, `AGENTIC_CONTROL.md`, `OPENCODE_SUPPORT.md`, `PROGRESS.md` |

The macOS non-applicable allowlist is explicit and currently limited to the patterns in the `documentation-only` row; these paths do not affect application, package, build, test, resource, toolchain, or enforcement behavior. Unknown paths, conflicting policy entries, missing policy data, malformed changed-file data, an incomplete or truncated pagination response, and a manifest at the supported API ceiling fail closed.

The gate reports `passed`, `failed`, `waiting`, `skipped`, `cancelled`, `timed-out`, `not-applicable`, `prerequisite-blocked`, and `disabled-policy` as distinct states. Only `passed` satisfies an applicable validation. The prerequisite relationships are declarative across the repository's separate workflows, so they do not create cross-workflow `needs` dependencies; when a prerequisite fails, the gate records that prerequisite as failed and the dependent macOS validation as blocked. Missing, stale, duplicate, ambiguous, unexpected-integration, and wrong-head results do not satisfy the gate.

`ENABLE_MACOSX_JOBS` is read from trusted repository configuration by `ci-gate`. The exact value `false` disables applicable pull-request macOS validation and is reported as `disabled-policy`; exact `true`, missing, malformed, or unavailable values require applicable pull-request macOS validation. Candidate workflow files, labels, inputs, and changed content cannot change this decision. Manual, scheduled, release, and other non-pull-request macOS workflows remain independently available.

The `ci-gate` summary and check output identify the evaluated head SHA, base-owned policy source and version, applicability reason, expected workflow/job/event/integration, observed evidence, terminal state, changed-file or API completeness error, and final decision. Reviewers should use that output to distinguish a validation failure from waiting, cancellation, a deliberate macOS opt-out, a blocked prerequisite, or an infrastructure/input failure.

The enforcement surface includes `.github/ci-gate-policy.json`, `.github/scripts/`, `.github/workflows/`, `.github/CODEOWNERS`, and `openspec/`. These paths remain covered by the human default in `.github/CODEOWNERS`; no agent-editable exception grants ownership of the gate contract or privileged validators. Action references in the enforcement surface must remain full commit SHA pins.

## Current OpenSpec enforcement before the gate migration

Until the repository owner completes and verifies the external ruleset transition, `openspec-check` remains the current required merge check. It runs on every pull request through the base-owned `pull_request_target` workflow and on pushes to the default branch. Its validation is strict for ordinary pull requests, drafts, and every layer of a formal stack. After the owner registers `ci-gate` and removes the old contexts, `ci-gate` becomes the authoritative required merge check described above:

| Invariant | Required result |
|---|---|
| An OpenSpec change is present in the candidate tree | pass |
| Required artifacts and matching main specifications exist | pass |
| Artifacts pass `openspec validate --all --strict` | pass |
| Archived-change validation passes | pass |
| Continuation layers preserve the shared active change set | pass |
| The current top or standalone layer archives the shared change set | pass |
| The current top or standalone layer has no active change and all tasks checked | pass |

Missing or malformed changes fail the check on every layer. Active or incomplete changes fail only when a current top or standalone layer attempts finalization; the guide comment and `openspec` label are informational, while the `openspec-check` job is the merge gate.

## GitHub merge controls and ownership

The `main` branch ruleset is external repository configuration. The target migration replaces the individual pull-request job contexts with the stable `ci-gate` check from the GitHub Actions integration, uses strict required-status enforcement, blocks force pushes and other non-fast-forward updates, and preserves code-owner review and thread resolution. Only the human account `JustinDFuller` may use the configured ruleset bypass. `JustinDFuller-Agents` must not have administrator, maintain, or ruleset-bypass permission. The ruleset is configured and verified manually; CI does not change repository administration settings.

| Control | Target contract |
|---|---|
| Required status | `ci-gate` from the `GitHub Actions` integration |
| Enforcement | `strict` required-status enforcement on `main` |
| Preserved controls | code-owner review, thread resolution, force-push protection, and other recorded branch protections |
| Bypass | `JustinDFuller` only; `JustinDFuller-Agents` has no administrator, maintain, or ruleset-bypass permission |
| Rollback | restore the complete recorded ruleset shape, re-read it, and verify every restored field |
| API target and ref | `target: branch`; `conditions.ref_name.include: ["~DEFAULT_BRANCH"]` or the exact recorded `refs/heads/main` condition |
| API enforcement and status | `enforcement: active`; `required_status_checks`; `strict_required_status_checks_policy: true`; `context: ci-gate` |
| API integration and protection | `integration_id: <GitHub Actions app id>`; `non_fast_forward` |

### Manual ruleset transition

The repository owner performs the transition only after the base-owned `ci-gate` workflow is available on `main` and a disposable pull request has produced the expected check. First record the current ruleset with `gh api repos/JustinDFuller/agent-session-manager/rulesets` and `gh api repos/JustinDFuller/agent-session-manager/rulesets/<ruleset-id>`, including required contexts, enforcement, bypass actors, code-owner review, thread resolution, and force-push restrictions. In the GitHub ruleset UI or an owner-approved API update, retain the target branch, strict required-status enforcement, code-owner review, thread resolution, force-push protection, and the human-only bypass, then replace the old individual validation contexts with `ci-gate` from the GitHub Actions integration. Re-read the ruleset and verify the resulting shape before merging a test pull request. If `ci-gate` is unavailable, restore the complete recorded prior ruleset shape, including contexts, enforcement, bypass actors, review settings, and force-push restrictions, then re-read it and verify every restored field; do not use a force push or a workflow mutation to bypass the ruleset.

For an API update, use the recorded ruleset as the full payload rather than constructing a partial replacement. The target contract is `target: branch`, `conditions.ref_name.include: ["~DEFAULT_BRANCH"]` (or the exact recorded `refs/heads/main` condition), `enforcement: active`, a `required_status_checks` rule whose `parameters.strict_required_status_checks_policy` is `true`, whose `parameters.required_status_checks` contains exactly `{ "context": "ci-gate", "integration_id": <GitHub Actions app id> }`, and a `non_fast_forward` rule. Obtain the numeric integration ID from a recent `ci-gate` check run's GitHub Actions app identity, compare it before the write, and verify the post-write ruleset has the expected target, ref condition, enforcement, bypass actors, required status entry, strictness, non-fast-forward rule, code-owner review, and thread-resolution settings. The API requires repository administration write permission, so the operation remains an explicit owner action and must not be placed in CI.

The ruleset migration is not complete while it exists only in this document or in a pull request. Until the owner performs and verifies the external change, the repository must not claim live `ci-gate` enforcement.

### Stacked merge review controls

Latest-push approval and stale-review dismissal are separate external policy changes. They can conflict with atomic stacked merges because merging a lower layer changes the merge base and can invalidate approvals or make the latest approved commit no longer the effective stack head. Do not enable either setting as part of the `ci-gate` migration. Before changing them, the repository owner must document and verify a stack-compatible merge procedure that preserves the immediate-parent bases, uses the formal `gh stack` workflow, never force-pushes a protected branch, and identifies how fresh approvals are obtained after each base change. Record owner approval and the disposable-stack evidence before changing the live ruleset.

This workflow change does not alter the existing `.github/CODEOWNERS` boundary.

The existing `.github/CODEOWNERS` policy remains in force:

- `JustinDFuller` owns the repository by default.
- Selected implementation paths remain intentionally agent-editable.
- The enforcement surface, including `.github/workflows/`, `.github/scripts/`, `.github/CODEOWNERS`, and `openspec/`, remains covered by the human default because no exception grants those paths to the agent.

The ruleset and CODEOWNERS policy are complementary: CODEOWNERS controls human review of enforcement changes, while the ruleset controls the required status, non-fast-forward protection, and its only authorized bypass.

## The OpenSpec guide comment

The base-owned `.github/workflows/openspec-guide.yml` workflow maintains a sticky pull request comment reporting OpenSpec status for same-repository pull requests. It checks out the exact candidate head with credentials disabled, exposes only the candidate `openspec/` directory to the pinned CLI from an isolated temporary root, disables npm install scripts, and removes credential-like environment variables before validation. It is purely informational and is not itself a required status check. Fork pull requests are reported as not applicable because the current job intentionally excludes them.

## The `openspec` label

Any pull request whose diff touches `openspec/` is labeled `openspec` automatically, so OpenSpec's impact on cycle time and quality can be measured. No contributor action is required.
