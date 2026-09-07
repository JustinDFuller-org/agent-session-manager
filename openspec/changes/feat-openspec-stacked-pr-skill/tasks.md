The implementation stack SHALL map one top-level task group to one implementation PR. All subtasks under a group remain in that same PR; for example, task group 2 includes `2.1` through `2.5` together. The final QA group belongs to the validation-only PR. Creating the formal stack, archiving in the top archive PR, marking PRs ready, and merging are workflow steps rather than implementation tasks.

## 1. Canonical stacked OpenSpec skill

- [ ] 1.1 Add `.agents/skills/openspec-stacked-prs/SKILL.md` with valid Agent Skills frontmatter and the repository-specific trigger conditions; verify it with `skills-ref validate .agents/skills/openspec-stacked-prs`.
- [ ] 1.2 Document new-stack and existing-PR flows using `gh stack init`, `gh stack add`, `gh stack submit`, and bottom-to-top `gh stack link`; verify the skill explicitly rejects `gh pr create --base` as proof of formal stack membership.
- [ ] 1.3 Document remote-stack import and verification using `gh stack checkout <top-pr>`, `gh stack view --json`, and per-PR `gh pr view`; verify the acceptance checklist requires both formal metadata and correct branch bases.
- [ ] 1.4 Document command side effects, GitHub App authentication, force-with-lease/rebase approval boundaries, conflict recovery, and merge confirmation; verify the guidance does not instruct agents to use personal authentication or unconditional merge commands.

## 2. Repository-level workflow guidance

- [ ] 2.1 Update `AGENTS.md` to require the canonical skill for multi-PR OpenSpec changes and define the OpenSpec, implementation, QA, and archive layer responsibilities; verify the task-group rule says all subtasks remain with their parent top-level task.
- [ ] 2.2 Update `openspec/README.md` to explain the formal `gh stack` linking/import/verification sequence and the phase-aware top-layer archive workflow; verify it no longer presents the bottom PR as the sole archive owner.
- [ ] 2.3 Link the canonical procedure from the existing OpenSpec workflow skill entrypoints without duplicating command details; verify every relevant entrypoint points to the same skill.

## 3. Phase-aware workflow compatibility

- [ ] 3.1 Cross-check the guidance against the phase-aware OpenSpec gate behavior represented by PRs #330 and #335, and verify the documented archive PR is top-layer-only and archive-only.
- [ ] 3.2 Add official GitHub documentation links for stacked-PR concepts, quickstart, and CLI commands; verify every command example matches the installed `gh stack` help and current official reference.

## 4. QA evidence

- [ ] 4.1 Run `skills-ref validate` for the new and modified skills, repository format/lint checks applicable to Markdown, and `openspec validate --all --strict`; record expected and observed results.
- [ ] 4.2 In a dedicated worktree, inspect a real formal stack with `gh stack checkout <top-pr>`, `gh stack view --json`, and `gh pr view` for every layer; record evidence that correct branch bases alone are insufficient and formal metadata is present.
