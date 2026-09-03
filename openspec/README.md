# OpenSpec in this repo

This repo uses [OpenSpec](https://openspec.dev)'s `opsx` workflow. It exists to close a gap: on a long-running agent session, the only durable record of what was actually asked for is the session itself — the commit log and the code faithfully record whatever the session drifted into, not necessarily what was agreed. OpenSpec makes the requirements a committed artifact a human reads and approves before implementation starts.

## Using it is optional

Nothing here is required. A pull request that touches no path under `openspec/` is unaffected by the checks and labeling described below.

## The command sequence

1. `/opsx:explore` — work out the requirements and open questions with the agent
2. `/opsx:propose` — write `proposal.md`, `specs/<capability>/spec.md`, `design.md`, and `tasks.md` for review; **no implementation yet**
3. Iterate on the spec with your reviewer(s) until it's locked in
4. `/opsx:apply` — implement `tasks.md`
5. PR review — human and AI feedback on the implementation and the spec
6. `/opsx:archive` — **after** review feedback on the change is resolved, and as the **last step** before marking the PR ready for review, not part of implementation
7. Merge

## Install OpenSpec

Install the repository's pinned OpenSpec CLI version:

```bash
npm install -g @fission-ai/openspec@1.10.0
```

The `/opsx:*` commands are OpenSpec workflows that run inside a supported AI coding assistant. Follow the [official OpenSpec setup guide](https://openspec.dev/docs/getting-started) to install the integration for your assistant. The `openspec` CLI must be on `PATH` before a workflow starts.

### Preserve the repository configuration

This repository has a curated `openspec/config.yaml`. Review the working-tree diff after running `openspec init` or `openspec update`, and do not overwrite that file with profile-generated defaults.

## What a reviewer should read

Read `specs/<capability>/spec.md`. It's the requirement contract, written to stand on its own. The other planning artifacts (`proposal.md`, `design.md`, `tasks.md`, `.openspec.yaml`) are working material for the agent and a historical record — they're collapsed by default in the GitHub diff so they don't compete for attention, but they remain fully visible to automated code review and are not out of scope for findings.

## If you disagree with a requirement

Stop reviewing the parts of the implementation affected by that requirement until the disagreement is resolved. Reviewing an implementation against a requirement you don't agree with wastes both sides' time.

## Archiving is the last step, not part of implementation

A change is archived only after review feedback on it has been resolved, immediately before the PR is marked ready for review. A pull request that is a draft is never held to being archived or to having a complete checklist — open one, iterate, and collect feedback without the `openspec-check` going red. Once a PR is marked ready for review (or a commit reaches `main`, directly or through the merge queue), the check requires the change to be archived with every task complete, on both the active and archived change.

### Tasks can only contain work completable before archiving

Because archiving happens before the PR is marked ready, and a ready PR must have every task complete, a task whose completion depends on the PR being marked ready, merged, or observed after merge can never be honestly checked. `tasks.md` should contain only work that's completable and verifiable before archiving. Verifying, archiving, marking the PR ready, and merging are the workflow itself, not tasks. Work that can only happen after merge belongs under a `## Follow-ups after merge` heading in `proposal.md` instead, linking a tracking issue when it needs an owner.

## What CI enforces, and when

`openspec-check` runs on every pull request and on pushes to the default branch. Structural validity is always enforced; the two "how far along is this" facts relax to notices on a draft PR so iterating on a change never shows as a failure:

| Invariant | Draft PR | Ready for review, or a commit on the default branch |
|---|---|---|
| Artifacts pass `openspec validate --all --strict` | error | error |
| No change outside `openspec/changes/archive/` | notice | error |
| All tasks checked — active and archived changes | notice | error |

A notice appears in the check's output but does not fail it — draft-mode findings surface as GitHub notices, not failures. Converting a PR back to draft re-relaxes a red check to green.

## The OpenSpec guide comment

The `.github/workflows/openspec-guide.yml` workflow maintains a sticky pull request comment reporting the status of each OpenSpec change touched by the pull request's cumulative diff against its base branch — not just the latest push. Each fact is a row prefixed with `✅`, `⚠️`, or `❌`. For each active change it shows whether its artifacts validate, how many tasks are complete, and whether it's archived, plus a plain-language next step; an archived change collapses to a single row reporting whether it still passes its own validation. The comment updates in place on later pushes rather than reposting, and is removed if a later push leaves the cumulative diff touching no OpenSpec change. It is purely informational — it reports what `openspec-check` already decided and is not itself a required status check.

## The `openspec` label

Any pull request whose diff touches `openspec/` is labeled `openspec` automatically, so OpenSpec's impact on cycle time and quality can be measured. No contributor action is required.
