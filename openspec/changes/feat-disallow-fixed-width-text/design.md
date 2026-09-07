## Context

The repository currently has no prose-wrapping check, while its tracked Markdown corpus contains fixed-width hard-wrapped paragraphs in public documentation, internal guidance, and agent skills. The existing pull-request quality workflow validates description length but does not inspect paragraph structure, and the existing OpenSpec workflow establishes the repository's base-owned immutable enforcement pattern.

The change is documentation and repository-policy work only. It must preserve Markdown rendering, avoid source-code changes, and wait for the pending top-layer OpenSpec archive workflow before the five-layer stack is opened.

## Goals / Non-Goals

**Goals:**

- Detect logical prose continuations deterministically without relying on a particular column width.
- Reuse one scanner contract for files, pull-request descriptions, and commit bodies.
- Keep enforcement independent of candidate-controlled workflow and validator changes.
- Migrate the existing tracked Markdown corpus with behavior-preserving formatting changes.
- Make the rule explicit for agents, commits, and pull requests.

**Non-Goals:**

- Formatting source-code comments or replacing the existing code-comment policy.
- Enforcing a maximum line length for long single-line prose.
- Rewriting Git history or changing historical pull-request descriptions.
- Automatically editing files, pull requests, branches, or GitHub rulesets from CI.

## Decisions

### Use logical-block detection instead of a width threshold

The validator will reject any non-empty continuation line within a logical prose block, even when the lines are short or do not share an exact width. A width heuristic was rejected because it would allow the same undesirable pattern whenever an author chose a different column limit.

### Use a small Markdown state machine with explicit structural exceptions

The scanner will track YAML front matter, fenced code, indented code, tables, headings, thematic breaks, list boundaries, blockquotes, and raw HTML blocks. It will report only prose continuations and will emit a repository-relative source label, line number, and concise reason. A full Markdown parser was rejected because the rule concerns physical block boundaries and the repository does not currently carry a Markdown parser dependency.

### Share the scanner contract across all communication channels

The local command and tests will expose file and text inputs through the same validation logic. CI will pass the complete candidate Markdown tree, the pull-request body from the trusted event payload, and the introduced commit messages from trusted GitHub metadata to that contract. This prevents local and remote checks from implementing subtly different definitions of a wrapped paragraph.

### Run enforcement from the protected base branch

The workflow will use a base-owned pull-request trigger with read-only permissions, check out enforcement code from the default branch, and inspect the candidate at its immutable head SHA. It will run on pull-request creation, edits, synchronization, reopening, and draft-state transitions, and it will not relax for drafts or stack layers. Candidate workflow or validator changes will therefore be scanned but not executed as enforcement logic.

### Scan the full candidate tree and introduced communication

The file scan will enumerate tracked Markdown-family files in the candidate tree, including unchanged files, so the repository cannot retain a known violation indefinitely. The pull-request and commit scans will cover only the current communication channels and commits introduced by that pull request; historical commit bodies are not rewritten or retroactively made merge blockers.

### Separate enforcement from migration

The implementation PR will add the scanner, tests, local command, CI, and guidance while the existing Markdown baseline remains visible. The migration PR will then reflow the baseline with a one-time mechanical helper that preserves structural exceptions and will be reviewed as a complete diff. CI will remain read-only and will not include an automatic fixer.

### Depend on the top-layer OpenSpec archive workflow

The stack will be opened only after the pending top-layer archive gate is available on `main`. The bottom draft PR will carry the active change, implementation and migration layers will preserve its identity, the QA layer will record evidence without archiving, and the final archive-only layer will perform the OpenSpec archive transition. No force-push will be used to bypass a failing check or rewrite reviewed history.

## Risks / Trade-offs

- [Risk] Markdown has syntax that resembles prose continuation. -> [Mitigation] Cover code, tables, front matter, HTML, headings, list boundaries, and blockquotes with explicit regression fixtures before scanning the full corpus.
- [Risk] A one-time reflow could change rendered Markdown or intentional spacing. -> [Mitigation] Preserve structural blocks, inspect the full migration diff, run documentation rendering/link checks, and require a clean post-migration scan.
- [Risk] Pull-request metadata may be incomplete or exceed API pagination limits. -> [Mitigation] Use trusted paginated metadata, fail closed on missing or truncated commit data, and include bounded diagnostics in QA evidence.
- [Risk] A stack layer may try to weaken the gate. -> [Mitigation] Load enforcement from the protected base branch and evaluate the immutable candidate without executing candidate enforcement code.
- [Risk] The migration produces a large review. -> [Mitigation] Keep the implementation and migration in separate PRs, use deterministic reflow, and report the number and paths of changed Markdown files in the migration PR.
