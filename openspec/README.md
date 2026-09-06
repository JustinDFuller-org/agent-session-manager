# OpenSpec in this repo

This repo uses [OpenSpec](https://openspec.dev)'s `opsx` workflow. OpenSpec
keeps the agreed requirements, design decisions, and implementation tasks in
the repository so a human can review the contract before implementation is
merged.

## Every pull request needs OpenSpec

Every pull request requires a complete, valid, archived OpenSpec change,
including drafts and pull requests that change only code, documentation,
automation, dependencies, or repository metadata. The `openspec-check` status
is strict on every pull request and every layer of a formal GitHub stacked pull
request. A draft does not relax the gate.

The required final state includes:

- the repository's spec-driven artifacts (`.openspec.yaml`, `proposal.md`,
  `design.md`, `tasks.md`, and a delta specification);
- a corresponding main specification under `openspec/specs/`;
- no `skip_specs` shortcut;
- every task checked; and
- no active change remaining under `openspec/changes/`.

The gate runs the pinned OpenSpec CLI with strict validation and archived-change
validation. It evaluates the immutable candidate revision for the pull request,
not scripts or workflows supplied by that candidate.

## The command sequence

1. `/opsx:explore` — work out the requirements and open questions with the agent
2. `/opsx:propose` — write `proposal.md`, `specs/<capability>/spec.md`,
   `design.md`, and `tasks.md` for review; **no implementation yet**
3. Iterate on the spec with your reviewer(s) until it is locked in
4. `/opsx:apply` — implement `tasks.md`
5. PR review — human and AI feedback on the implementation and the spec
6. Complete every task and run the required checks. If the remaining tasks are
   QA or validation, use a final validation-only stacked PR and record the
   commands, results, and evidence links in that PR's description.
7. `/opsx:archive` — archive the change as the last OpenSpec step, after review
   feedback is resolved and before the pull request is marked ready for review
8. Merge

### Stacked pull requests

For a formal stack rooted at `main`, the bottom PR owns the OpenSpec change.
Higher PRs contain implementation layers and must not archive the change or
create a competing finalized change.

While implementation proceeds, higher PRs may show the same strict check
failure because the base PR is still active or has incomplete tasks. That is
expected. Do not archive in the higher PR. Instead:

1. Finish the implementation work in the higher PRs.
2. Return to the base PR, complete the task checklist, and archive the change
   there.
3. Cascade-rebase the stack so the higher branches contain the archived state.
4. Rerun the checks, then mark the stack ready and merge it.

For a higher-layer failure, CI explicitly says not to archive in that PR and
points to the base branch when available. For a base-layer failure, CI directs
the contributor to complete and archive the change in that base PR.

#### Validation-only final layer

When the remaining tasks are QA or validation rather than implementation, the
last stacked PR may be a validation-only layer. That PR should check off the
validation tasks only after running them and its description must record:

- the exact commands, workflows, and GitHub API checks that were run;
- the expected and observed result for each check;
- links to useful CI runs, ruleset evidence, or other durable evidence; and
- any disposable diagnostic workflow or fixture used, including confirmation
  that it was removed afterward.

The validation-only PR still must not archive the OpenSpec change. After the
validation results are reviewed, return to the base PR to complete any
remaining task checklist items, archive the change there, cascade-rebase the
stack, and rerun the final checks.

## Install OpenSpec

Install the repository's pinned OpenSpec CLI version:

```bash
npm install -g @fission-ai/openspec@1.10.0
```

The `/opsx:*` commands are OpenSpec workflows that run inside a supported AI
coding assistant. Follow the [official OpenSpec setup guide](https://openspec.dev/docs/getting-started)
to install the integration for your assistant. The `openspec` CLI must be on
`PATH` before a workflow starts.

### Preserve the repository configuration

This repository has a curated `openspec/config.yaml`. Review the working-tree
diff after running `openspec init` or `openspec update`, and do not overwrite
that file with profile-generated defaults.

## What a reviewer should read

Read `specs/<capability>/spec.md`. It is the requirement contract, written to
stand on its own. The other planning artifacts (`proposal.md`, `design.md`,
`tasks.md`, `.openspec.yaml`) are working material for the agent and a
historical record; they remain visible to automated code review and are not out
of scope for findings.

## If you disagree with a requirement

Stop reviewing the parts of the implementation affected by that requirement
until the disagreement is resolved. Reviewing an implementation against a
requirement you do not agree with wastes both sides' time.

## Archiving is the last OpenSpec step

A change is archived only after review feedback on the change has been
resolved, immediately before the pull request is marked ready for review. The
archive is required even when the pull request is a draft; keeping a draft only
allows the work to remain under review while the strict check explains what is
still missing.

Tasks must describe work that can be completed and verified before archiving.
Verifying, archiving, marking the pull request ready, and merging are the
workflow itself, not tasks. Work that can only happen after merge belongs under
a `## Follow-ups after merge` heading in `proposal.md`, with a tracking issue
when it needs an owner.

## What CI enforces

`openspec-check` runs on every pull request through the base-owned
`pull_request_target` workflow and on pushes to the default branch. Its
validation is strict for ordinary pull requests, drafts, and every layer of a
formal stack:

| Invariant | Required result |
|---|---|
| An OpenSpec change is present in the candidate tree | pass |
| Required artifacts and matching main specifications exist | pass |
| Artifacts pass `openspec validate --all --strict` | pass |
| Archived-change validation passes | pass |
| No active change remains outside `openspec/changes/archive/` | pass |
| All tasks are checked in the relevant change set | pass |

Missing, malformed, active, incomplete, or unarchived changes fail the check.
The `openspec-check` job is the merge gate; the guide comment and `openspec`
label are informational only.

## GitHub merge controls and ownership

The `main` branch ruleset is external repository configuration. It must require
the stable `openspec-check` status in addition to the repository's existing
review, code-owner, latest-push approval, and thread-resolution requirements.
Only the human account `JustinDFuller` may use the configured ruleset bypass.
`JustinDFuller-Agents` must not have administrator, maintain, or ruleset-bypass
permission.

The existing `.github/CODEOWNERS` policy remains in force:

- `JustinDFuller` owns the repository by default.
- Selected implementation paths remain intentionally agent-editable.
- The enforcement surface, including `.github/workflows/`,
  `.github/scripts/`, `.github/CODEOWNERS`, and `openspec/`, remains covered by
  the human default because no exception grants those paths to the agent.

The ruleset and CODEOWNERS policy are complementary: CODEOWNERS controls human
review of enforcement changes, while the ruleset controls the required status
and its only authorized bypass.

## The OpenSpec guide comment

The `.github/workflows/openspec-guide.yml` workflow maintains a sticky pull
request comment reporting OpenSpec status. It is purely informational and is
not itself a required status check.

## The `openspec` label

Any pull request whose diff touches `openspec/` is labeled `openspec`
automatically, so OpenSpec's impact on cycle time and quality can be measured.
No contributor action is required.
