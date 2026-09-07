## Why

Agent Session Manager uses OpenSpec changes across formal GitHub stacked pull requests, but existing guidance does not make the `gh stack` metadata workflow explicit. Agents can create correct branch bases with `gh pr create --base` while leaving pull requests outside a formal GitHub stack, causing stack-aware OpenSpec validation and review coordination to behave incorrectly.

## What Changes

- Add a canonical agent skill for creating, linking, importing, verifying, updating, and safely merging OpenSpec-backed GitHub stacks with `gh stack`.
- Document the fixed layer contract: one OpenSpec layer, one implementation PR per top-level task group with all of that task's subtasks together, one validation-only QA layer, and one top-layer archive PR.
- Require formal stack verification with `gh stack view --json` in addition to checking every pull request's base branch with `gh pr view`.
- Update `AGENTS.md`, `openspec/README.md`, and the OpenSpec workflow skill entrypoints to reference the canonical procedure.
- Document authentication and remote-history safety boundaries for `gh stack link`, `submit`, `push`, `sync`, `rebase`, and `merge`.

### Deliberately out of scope

- Changing the GitHub Actions OpenSpec gate or its phase-aware archive semantics; those are represented by the separate phase-aware gate work and must be available before this workflow is used.
- Changing GitHub authentication, remotes, credential helpers, repository rulesets, or branch protection.
- Adding application source, runtime behavior, public product APIs, or automated remote stack mutations.
- Replacing the official GitHub stacked pull request documentation; repository guidance will link to it and describe only the project-specific workflow.

## Capabilities

### New Capabilities

- `openspec-stacked-prs`: Agent guidance for maintaining a formally linked GitHub stack whose layers collectively carry one OpenSpec change through implementation, QA, and archive.

### Modified Capabilities

- None.

## Impact

- Agent-facing documentation under `AGENTS.md`, `openspec/README.md`, and `.agents/skills/`.
- OpenSpec planning artifacts and validation expectations for multi-PR changes.
- No application code, dependencies, persisted user data, or runtime interfaces.
