## Why

OpenSpec is currently enforced only when a pull request touches `openspec/`, and draft pull requests may downgrade incomplete work to notices. The repository therefore cannot guarantee that every merged change has a reviewed, well-formed, completed, and archived requirements record, nor that the agent account cannot weaken the gate.

## What Changes

- Require every pull request, including drafts and pull requests that change only code, documentation, or automation, to include a complete OpenSpec change.
- Require the change to use the repository's spec-driven artifacts, pass strict validation, have every task completed, update the main spec, and be archived before the required check passes.
- Run the enforcement logic from the base branch with read-only permissions while validating the pull request commit, so pull request changes cannot replace the gate logic.
- Keep the required status check stable and document the GitHub ruleset configuration that makes it a merge prerequisite.
- Restrict the ruleset bypass to `JustinDFuller`; preserve the existing `CODEOWNERS` policy for ordinary agent-editable paths while keeping the enforcement surface human-owned.
- Update the OpenSpec repository guide so its documented lifecycle and draft behavior match the mandatory gate.

## Capabilities

### New Capabilities

- `openspec-merge-gate`: Enforces that every pull request carries a valid, task-complete, archived OpenSpec change and exposes a required merge status controlled by the human repository owner.

### Modified Capabilities

- None.

## Impact

- GitHub Actions workflow and supporting validation logic under `.github/`.
- OpenSpec workflow documentation in `openspec/README.md`.
- Repository-level GitHub ruleset configuration for the `main` branch, including the required `openspec-check` status and direct-user bypass restriction.
- CI validation and fixture coverage for missing, malformed, incomplete, active, unarchived, and valid archived changes.

### Deliberately out of scope

- Expanding `JustinDFuller` ownership to ordinary source, test, asset, script, or documentation paths that the existing `CODEOWNERS` policy intentionally leaves agent-editable.
- Replacing OpenSpec's configured schema or changing the OpenSpec CLI version independently of this enforcement work.
- Making the informational guide comment or `openspec` label a required merge condition.
