## Context

See `proposal.md` for the motivation. The repository already has OpenSpec workflow skills and an internal `openspec/README.md`, but their stack guidance predates the repository's use of GitHub's formal stacked pull request metadata. The current phase-aware gate work permits the current top layer to perform final archive work, while older guidance still describes the base PR as the sole archive owner.

GitHub distinguishes the branch dependency chain from formal stack membership. `gh stack link` creates or updates the remote stack, `gh stack checkout` imports a remote stack into local tracking, and `gh stack view --json` exposes the resulting local stack state. The official CLI also documents that `gh stack sync` and stack pushes can use force-with-lease updates, so the repository's no-force-push policy must be visible at the command boundary.

## Goals / Non-Goals

**Goals:**

- Make the formal stack lifecycle and verification sequence unambiguous to coding agents.
- Centralize detailed `gh stack` command guidance in one discoverable skill.
- Keep `AGENTS.md`, `openspec/README.md`, and OpenSpec workflow skills aligned with that canonical procedure.
- Encode the phase-aware OpenSpec responsibilities for implementation, QA, and archive layers.

**Non-Goals:**

- Change the OpenSpec merge-gate implementation or GitHub ruleset configuration.
- Automate remote stack creation, rebasing, force-with-lease pushes, or merging.
- Add public product documentation or application behavior.

## Decisions

### Use one canonical operational skill

Add `.agents/skills/openspec-stacked-prs/SKILL.md` as the detailed command reference and workflow. `AGENTS.md`, `openspec/README.md`, and the existing OpenSpec workflow skills will contain short references to it rather than independent copies of the command procedure. This minimizes drift while keeping the workflow discoverable from repository-level and phase-specific guidance.

### Treat formal metadata as a required acceptance condition

The skill will show separate procedures for new stacks and already-created pull requests. New stacks may use `gh stack init`, `gh stack add`, and `gh stack submit`; existing pull requests must use `gh stack link` in bottom-to-top order. Every path ends with `gh stack checkout <top-pr>`, `gh stack view --json`, and per-PR `gh pr view` base verification. The skill will explicitly reject `gh pr create --base` as sufficient proof of formal stack membership.

### Map OpenSpec phases to stack positions

The bottom layer introduces the shared OpenSpec change. Each implementation layer owns one top-level task group and every subtask in that group. A task group such as `2` with subtasks `2.1` through `2.5` is one stack PR, never five stack PRs. The QA layer records validation without archiving. The current top archive layer completes and archives the change, and must remain archive-only. This mapping matches the phase-aware gate work in PRs #330 and #335 and must be landed with or after that gate behavior.

### Make remote mutation and authentication boundaries explicit

Inspection commands are presented separately from commands that push, alter pull request bases, rewrite branch history, or merge. `gh stack sync` and `gh stack push` will be identified as force-with-lease-capable operations; `gh stack rebase` will be identified as changing commit identities and requiring approval before any subsequent push. The skill will direct agents to the existing App-backed `gh` wrapper and the repository authentication setup document.

### Keep the repository guide authoritative for policy

`AGENTS.md` will state when to load the skill and the mandatory acceptance rules. `openspec/README.md` will explain how those rules interact with the OpenSpec gate, task completion, QA evidence, and archive timing. The skill will own command syntax and recovery guidance. No new public documentation page is needed because this is internal agent/process guidance.

## Risks / Trade-offs

- [Risk] GitHub's stacked pull request feature and `gh stack` extension are in public preview and may change. -> [Mitigation] Link to the official GitHub overview, quickstart, and CLI reference, and validate examples against the installed CLI during QA.
- [Risk] A branch can be correctly based while lacking formal stack metadata. -> [Mitigation] Make `gh stack link` and `gh stack view --json` mandatory for acceptance.
- [Risk] `gh stack sync` or a post-rebase push can rewrite remote branch history. -> [Mitigation] Require explicit approval and preserve the no-force-push policy boundary.
- [Risk] Documentation could describe the archive layer before the phase-aware gate is available on the base branch. -> [Mitigation] Make the phase-aware gate a landing dependency and verify the final stack against its current behavior.
