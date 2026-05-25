---
name: ship
description: "Commit, push, ensure a PR exists, capture screenshots, and attach them to the PR."
---

# Ship

Commit, push, ensure a PR exists, capture screenshots, and attach them to the PR.

## Step 1: Gather info

Run these commands to understand current state:

```bash
git status
git diff HEAD
git log --oneline -10
git branch --show-current
```

## Step 2: Commit

If there are no staged or unstaged changes, skip to Step 3.

Stage all relevant changes (be specific — avoid `git add .` if sensitive files are present). Draft a conventional commit message in present tense that focuses on "why" over "what", following the repository's existing commit style. End the message with:

```
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Run the commit. The pre-commit hook runs unit tests, swift-format, and swiftlint — if it fails, fix the issue and recommit.

## Step 3: Push

```bash
git push -u origin $(git branch --show-current)
```

Never force-push. The pre-push hook runs UI smoke tests — if it fails, fix the issue before retrying.

## Step 4: Ensure a PR exists

```bash
gh pr view --json url,state 2>/dev/null || true
```

If no PR exists, create a draft PR using this body template:

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

Create it with:
```bash
gh pr create --draft --title "<type>: brief summary" --body "<body>"
```

## Step 5: Capture and attach screenshots

```bash
make pr-screenshots
```

This runs both screenshot test classes, captures all 11 PNGs in `./screenshots/`, uploads them to the configured gist, and rewrites the `## Example` section of the PR body. It takes several minutes — the app must build and UI tests must run.

## Step 6: Report

Print the PR URL and confirm which screenshots were attached. Note that `/ship` does not replace full `make test-ui-dev` verification.

## Rules

- Never force-push
- Never commit files that likely contain secrets (.env, credentials, keys)
- If there are no changes to commit and the branch is already pushed, skip straight to Step 4
- Do not deviate from the PR body template — the `## Example` anchor is required for the screenshot script
