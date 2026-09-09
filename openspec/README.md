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

The `ci-gate` job in `.github/workflows/ci-gate.yml` is the single native pull-request orchestration result. The workflow runs on opened, edited, synchronized, reopened, ready-for-review, and converted-to-draft events whose stack trunk is `main`; GitHub evaluates stacked pull requests against that trunk. The caller invokes each required validation as a local reusable workflow and its final gate depends on every caller with `if: always()`.

| Caller job | Reusable workflow | Native validation | MacOS | Prerequisites |
|---|---|---|---|---|
| `pr_quality` | `.github/workflows/pr-quality.yml` | PR description | no | none |
| `openspec` | `.github/workflows/openspec.yml` | OpenSpec check | no | none |
| `no_code_comments` | `.github/workflows/no-code-comments.yml` | no-code-comments | no | none |
| `no_fixed_width_prose` | `.github/workflows/no-fixed-width-prose.yml` | fixed-width prose | no | none |
| `swift_format` | `.github/workflows/format.yml` | swift-format | no | none |
| `swiftlint` | `.github/workflows/lint.yml` | SwiftLint | no | none |
| `docs` | `.github/workflows/docs.yml` | documentation | no | none |
| `resolve` | `.github/workflows/swift-build-check.yml` | package resolution | no | none |
| `unit_tests` | `.github/workflows/unit-tests.yml` | `swift test` | yes | preflight and all lightweight callers |
| `ui_tests` | `.github/workflows/ui-tests.yml` | `make test-ui-dev-launch` | yes | preflight and all lightweight callers |
| `compatibility` | `.github/workflows/dependency-toolchain-compatibility.yml` | dependency and toolchain compatibility | yes | preflight and all lightweight callers |

Every required validation workflow has a `workflow_call` entry point. Push, schedule, and manual entry points remain on the workflows where they are useful outside pull-request accounting. Required workflow files are not path-filtered; the caller runs for every gateable revision.

### MacOS preflight

The `macos_preflight` job checks out the exact pull-request head with credentials disabled and compares the stack base SHA, falling back to the immediate pull-request base SHA, to that head with Git. It emits exactly one `macos_mode`: `required`, `disabled-policy`, or `not-applicable`.

| Input | Result |
|---|---|
| Every changed path is in the documentation-only allowlist | `not-applicable` |
| Any relevant classified path and `ENABLE_MACOSX_JOBS` is exactly `false` | `disabled-policy` |
| Any source, test, package, project, build, resource, toolchain, or enforcement path | `required` |
| Unknown path, invalid revision, incomplete diff, missing variable, or malformed variable | fail closed; required validation is never reduced |

The documentation-only allowlist is `documentation/**`, `README.md`, `USER_FACING_DOCS.md`, `AGENTS.md`, `CLAUDE.md`, `AGENTIC_CONTROL.md`, `OPENCODE_SUPPORT.md`, and `PROGRESS.md`. The preflight classifier and tests in `.github/scripts/macos-preflight.mjs` and `.github/scripts/macos-preflight.test.mjs` are the source for the exact Git matching behavior.

### Native dependency and gate behavior

MacOS callers require the preflight and every lightweight caller to succeed, and run only when `macos_mode=required`. A failed lightweight caller short-circuits expensive macOS work; the final gate remains failed and reports the prerequisite. `disabled-policy` and `not-applicable` intentionally skip all three macOS callers and are reported as policy decisions, never as test passes.

The final `ci-gate` job accepts successful lightweight callers and successful macOS callers when required. It accepts skipped macOS callers only for the two explicit preflight modes. It fails for a failed, cancelled, or unexpectedly skipped preflight or required caller, and its summary reports the preflight mode, reason, and every native job result. Concurrency cancels superseded pull-request revisions so an older result cannot satisfy a newer head.

The caller and every reusable workflow use empty default permissions, explicit job-level least privilege, full commit-SHA action pins, and disabled checkout credentials. The gate performs no API polling, check-run discovery, candidate-policy loading, or cross-run correlation.

OpenSpec guide comments and the `openspec` label are maintained by the separate best-effort `.github/workflows/openspec-guide.yml` workflow. They are not caller jobs and are not dependencies of `ci-gate`. The title-based WIP action was removed; native draft pull-request state remains the merge control for drafts.

### GitHub ruleset and stack migration

The formal migration is bottom-to-top: revised proposal #353, one replacement implementation pull request replacing #354, #356, and #357, guidance #358, QA #359, and archive #361. Use `gh stack modify` to drop the obsolete implementation branches and insert the replacement, then `gh stack submit`. Close replaced pull requests only after `gh stack view --json` shows the five-layer formal stack and every pull request targets its immediate parent branch.

Before changing the live ruleset, record its complete JSON and confirm a real `ci-gate` check is available on `main`. With explicit owner approval, replace the individual required status contexts with exactly `ci-gate` from the `GitHub Actions` integration. Preserve active enforcement, strict required-status behavior, code-owner approval, thread resolution, squash-only merging, non-fast-forward protection, and the existing human-only bypass. Re-read the complete ruleset after the update.

If `ci-gate` is unavailable, restore the complete recorded ruleset payload and verify every field again. The bot-authenticated agent must not change authentication, force-update `main`, or bypass the ruleset. Feature-branch rewrites are permitted only with `--force-with-lease` after branch protection coverage is checked.

Latest-push approval and stale-review dismissal are not part of this migration. They can conflict with atomic stacked merges; enable either only after the owner documents and verifies a stack-compatible merge procedure with fresh approvals and no force-push of protected branches.

Until the owner completes and verifies the external ruleset update, documentation and QA must not claim live `ci-gate` enforcement. The existing `.github/CODEOWNERS` boundary remains in force and continues to require human review for the enforcement surface.

## The OpenSpec guide comment

The base-owned `.github/workflows/openspec-guide.yml` workflow maintains a sticky pull request comment reporting OpenSpec status for same-repository pull requests. It checks out the exact candidate head with credentials disabled, exposes only the candidate `openspec/` directory to the pinned CLI from an isolated temporary root, disables npm install scripts, and removes credential-like environment variables before validation. It is purely informational and is not itself a required status check. Fork pull requests are reported as not applicable because the current job intentionally excludes them.

## The `openspec` label

Any pull request whose diff touches `openspec/` is labeled `openspec` automatically, so OpenSpec's impact on cycle time and quality can be measured. No contributor action is required.
