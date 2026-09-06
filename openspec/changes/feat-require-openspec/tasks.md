## 1. Base-owned enforcement

- [ ] 1.1 Convert `.github/workflows/openspec.yml` to an unconditional `pull_request_target` gate that runs for every relevant pull request event, keeps `openspec-check` as the stable job name, uses read-only permissions, applies the same strict result to every stack layer, and verifies the workflow still parses with the repository's CI validation command.
- [ ] 1.2 Add the base-owned OpenSpec validator that checks the cumulative pull request file set for an archived change and corresponding main specification, rejects active changes and `skip_specs`, verifies the required spec-driven artifacts, and runs strict full and archived validation against the isolated pull request checkout; verify its failure messages and exit status locally.
- [ ] 1.3 Check out pull request contents by repository and immutable head SHA without executing candidate scripts, workflows, hooks, or package code; verify with a review of the workflow permissions and a test pull request containing modified enforcement logic.
- [ ] 1.4 Add stack-aware failure guidance using the available pull request stack metadata without relaxing validation: identify the base-stack PR as the archive owner, tell higher implementation PRs not to archive, and verify the workflow fails closed when stack metadata is absent or malformed.

## 2. Regression coverage

- [ ] 2.1 Add deterministic validator coverage for a pull request with no OpenSpec files, verifying that an empty validator report fails with an actionable missing-change error.
- [ ] 2.2 Add coverage for active changes, missing metadata or artifacts, missing main specs, malformed specifications, unchecked tasks, and `skip_specs`, verifying each case fails closed.
- [ ] 2.3 Add coverage for a valid archived change with complete tasks and synchronized specs, verifying the validator passes; include draft-event inputs to prove draft status does not relax failures.
- [ ] 2.4 Add cumulative-diff coverage for changes spread across multiple commits and for a fork-style head repository, verifying that the gate evaluates the full pull request revision and resolves the head SHA safely.
- [ ] 2.5 Add stacked-PR coverage for an incomplete base PR and higher implementation PRs, verifying every layer fails strictly, the higher-layer message says not to archive there, and the base-layer message directs completion and archiving in the base PR followed by cascade rebase.

## 3. Documentation and repository policy

- [ ] 3.1 Update `openspec/README.md` so every pull request and every stack layer requires a complete archived OpenSpec change, draft failures remain blocking, and the required artifact and validation expectations are explicit; document that only the base PR completes tasks and archives, higher PRs must not archive, and the stack must be cascade-rebased afterward; verify the documented command sequence matches the workflow.
- [ ] 3.2 Document the external `main` ruleset prerequisites and the preserved `CODEOWNERS` boundary, verifying that the OpenSpec enforcement surface remains covered by `JustinDFuller` without changing intentional agent-editable paths.
- [ ] 3.3 Keep the CI failure text and `openspec/README.md` workflow instructions synchronized, verifying that a higher-layer failure cannot tell an agent to archive the change in that higher PR.

## 4. GitHub merge controls

- [ ] 4.1 Configure the `main` ruleset to require the observed `openspec-check` status and preserve the existing review, code-owner, last-push, and thread-resolution requirements; verify the ruleset JSON reports the required check.
- [ ] 4.2 Replace the repository-role bypass on the `main` ruleset with a direct `JustinDFuller` user bypass and verify `JustinDFuller-Agents` has no admin, maintain, or ruleset-bypass permission.
- [ ] 4.3 Exercise representative failing and passing pull requests with the configured ruleset, verifying that the agent cannot merge without the OpenSpec check and that only the human account can perform the configured bypass.

## 5. Focused verification

- [ ] 5.1 Run the OpenSpec validator regression suite, `openspec validate --all --strict`, the repository workflow/lint checks, and the GitHub ruleset API verification; record successful results before the change is archived.
