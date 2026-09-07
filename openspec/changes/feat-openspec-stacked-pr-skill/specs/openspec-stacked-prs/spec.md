## Purpose

This capability gives coding agents a reliable, repository-specific procedure for carrying one OpenSpec change through a formally linked GitHub stacked pull request sequence.

## ADDED Requirements

### Requirement: The stacked OpenSpec lifecycle is explicit

The repository guidance SHALL define a fixed bottom-to-top lifecycle consisting of an OpenSpec PR, one implementation PR per top-level OpenSpec task group containing all of that task's subtasks, a validation-only QA PR, and a top-layer archive PR.

#### Scenario: An agent plans a multi-PR OpenSpec change

- **WHEN** the change requires dependent pull requests
- **THEN** the agent SHALL assign each top-level OpenSpec task group to one implementation layer, keep every subtask in that group in the same layer, reserve a validation-only QA layer, and reserve the top layer for archive work
- **AND** higher layers SHALL carry the same change rather than creating competing OpenSpec changes

#### Scenario: A task group has multiple subtasks

- **WHEN** task group `2` contains subtasks `2.1` through `2.5`
- **THEN** the implementation PR for task group `2` SHALL contain all subtasks `2.1` through `2.5`
- **AND** the agent SHALL NOT create separate stack PRs for individual subtasks

#### Scenario: A QA layer is added

- **WHEN** implementation tasks are complete and validation remains
- **THEN** the QA PR SHALL contain validation work and durable evidence
- **AND** it SHALL NOT archive the OpenSpec change

#### Scenario: The archive layer is finalized

- **WHEN** the archive PR is the current top layer and review feedback is resolved
- **THEN** the archive PR SHALL complete the remaining OpenSpec checklist and archive the shared change
- **AND** its diff SHALL contain only archive/finalization work allowed by the phase-aware OpenSpec gate

### Requirement: Formal GitHub stack metadata is created and verified

The repository guidance SHALL require agents to create or update GitHub's formal stack metadata in addition to creating the correct branch dependency chain.

#### Scenario: Existing pull requests already have the correct bases

- **WHEN** an agent has created dependent pull requests with `gh pr create --base`
- **THEN** the agent SHALL still run `gh stack link` with the pull requests or branches in bottom-to-top order
- **AND** the agent SHALL NOT consider the stack formal based only on matching base branches

#### Scenario: A remote stack is imported locally

- **WHEN** the stack exists on GitHub but is not tracked in the current worktree
- **THEN** the agent SHALL run `gh stack checkout` using the top pull request, stack number, URL, or unambiguous branch
- **AND** the local stack state SHALL be inspected before implementation or rebasing continues

#### Scenario: Stack creation is verified

- **WHEN** stack creation, linking, or submission completes
- **THEN** the agent SHALL run `gh stack view --json` and confirm the formal stack contains the expected ordered pull requests
- **AND** the agent SHALL run `gh pr view` for every layer and confirm each base branch targets the layer immediately below it
- **AND** the stack SHALL remain not ready if either formal metadata or branch-chain verification is missing

### Requirement: Stack commands have explicit side-effect boundaries

The repository guidance SHALL distinguish read-only inspection, local checkout/rebase operations, remote branch updates, pull request creation/linking, and stack merging, and SHALL require explicit approval for remote history rewriting or merge operations.

#### Scenario: An agent inspects stack state

- **WHEN** an agent needs to verify stack membership or ordering
- **THEN** it SHALL prefer `gh stack view --json` and `gh pr view` without changing remote state

#### Scenario: An agent updates a stack remotely

- **WHEN** an agent considers `gh stack link`, `gh stack submit`, `gh stack push`, `gh stack sync`, or a push after `gh stack rebase`
- **THEN** the guidance SHALL identify the command's branch, pull request, or history-rewriting effects
- **AND** the agent SHALL obtain explicit approval before a command can rewrite remote history

#### Scenario: An agent merges a stack

- **WHEN** all required review, OpenSpec, and validation conditions are satisfied
- **THEN** `gh stack merge` SHALL remain an explicitly approved operation
- **AND** the agent SHALL NOT use an unconditional non-interactive merge as part of ordinary implementation or QA

### Requirement: GitHub App authentication remains the repository command path

The stacked workflow SHALL direct agents to use the repository's configured GitHub App-backed `gh` wrapper and SHALL NOT instruct them to replace it with personal authentication.

#### Scenario: An agent checks GitHub CLI readiness

- **WHEN** stack commands require GitHub access
- **THEN** the agent SHALL verify the configured `gh` command and authentication health without printing credentials
- **AND** it SHALL stop and report the authentication problem rather than running `gh auth login` or substituting a personal token
