---
name: ship
description: "Commit, push, ensure a PR exists, capture screenshots, and attach them to the PR."
---

# Ship

This skill is a thin wrapper over `scripts/ship.sh`. Do not perform the steps the script performs — invoke the script and let it drive.

## Step 1: Gather state

Run these in parallel:

```bash
git status
git diff HEAD
git log --oneline -10
git branch --show-current
gh pr view --json url,state 2>/dev/null || true
```

## Step 2: Draft commit message (if needed)

If the working tree has staged or unstaged changes, draft a conventional-commit message in present tense that focuses on "why" over "what", following the repository's existing commit style. End the message with:

```
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Write it to `.ship-commit-msg` (gitignored).

## Step 3: Draft PR title and body (if needed)

If no PR exists for the current branch, draft a PR title and body using this template:

```
> [!NOTE]
> This PR title, description, and code were generated with Claude Code.

## Summary

One or two sentence overview.

## Changes

* change one, one sentence
* change two, also one sentence
* no more than ten bullet points

## Example

Screenshots go here instead of a comment
```

Write the body to `.ship-pr-body.md` (gitignored).

## Step 4: Invoke the script

Build the `bash scripts/ship.sh` invocation from what you gathered:

- Include `--commit-msg-file .ship-commit-msg` only if there were changes to commit.
- Include `--pr-title "..."` and `--pr-body-file .ship-pr-body.md` only if no PR existed.
- Include `--screenshots-only` only if no commit is needed and a PR already exists.

Example (commit + new PR):
```bash
bash scripts/ship.sh \
  --commit-msg-file .ship-commit-msg \
  --pr-title "feat: brief summary" \
  --pr-body-file .ship-pr-body.md
```

Example (already committed and PR exists):
```bash
bash scripts/ship.sh --screenshots-only
```

## Step 5: Handle failure

If the script exits non-zero, read the `INVARIANT VIOLATED:` line it printed. Investigate the named root cause — for example, if `build-screenshots` failed, read the Xcode test logs from `$RESULTS_PATH`. Fix the root cause, then re-invoke `scripts/ship.sh` with the same flags.

**Do not** silently retry, bypass the invariant, or improvise an alternative path.

## Step 6: Report

Print the PR URL the script printed on its final line.

## Rules

- Never force-push
- Never commit files that likely contain secrets (.env, credentials, keys)
- Never skip the script and perform steps by hand
- Never introduce a new fake or injected screenshot to satisfy `ship`; the `## Example` images must reflect real app behavior (see issue #221)
