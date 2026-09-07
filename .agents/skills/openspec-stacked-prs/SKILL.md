---
name: openspec-stacked-prs
description: Use when an OpenSpec change spans dependent GitHub pull requests or when creating, linking, importing, or verifying a formal gh stack.
license: MIT
compatibility: Requires GitHub CLI with the gh-stack extension installed.
metadata:
  author: Agent Session Manager
  version: "1.0"
---

# OpenSpec stacked pull requests

Use this skill when one OpenSpec change is being delivered across dependent GitHub pull requests. The goal is to create and verify GitHub's formal stack metadata, not merely a matching chain of pull request base branches.

## The critical distinction

`gh pr create --base <branch>` establishes a branch dependency. It does not prove that GitHub has created formal stacked pull request metadata. A stack is not ready until both conditions are true:

1. Every pull request targets the immediately preceding branch.
2. `gh stack view --json` shows the expected formal stack and order.

## Layer task grouping

One implementation pull request owns one top-level OpenSpec task group and every subtask in that group. If task group `2` contains `2.1` through `2.5`, keep all five subtasks in the same stack pull request. Do not create one pull request per subtask.

## Before using the CLI

Run the commands from the intended repository worktree. Confirm the worktree is the one that should track the stack and inspect uncommitted changes before commands that check out branches or rebase them.

Check that the extension is available:

```bash
gh --version
gh stack --help
```

Follow the repository's GitHub authentication instructions. Do not replace the configured authentication or credential flow to make a stack command work.

## Create a new stack

Use this flow when the branches or pull requests do not exist yet:

```bash
gh stack init
gh stack add <next-branch>
gh stack add <another-branch>
gh stack submit
```

`gh stack init` can also adopt or create explicit branches in order:

```bash
gh stack init <bottom-branch> <next-branch> <top-branch>
```

`gh stack submit` pushes the stack, creates or updates pull requests, and creates or updates the formal GitHub stack. Use `gh stack push` only when branches need to be pushed without creating or updating pull requests.

## Link pull requests that already exist

Use this flow when pull requests were created separately, including when they were created with `gh pr create --base`:

```bash
gh stack link <bottom-pr> <next-pr> <top-pr>
```

Arguments are always bottom-to-top. Pull request numbers and pull request URLs are accepted. Prefer full pull request URLs when a number could be confused with a GitHub stack number.

For example:

```bash
gh stack link 332 333
```

The link operation creates or updates GitHub's formal stack. It is additive for existing stacks; it does not remove already-linked pull requests. Branch arguments can also push branches and create missing pull requests, so inspect the command's intended inputs before using branch names.

## Import and verify the remote stack

After `gh stack link` or `gh stack submit`, import the remote stack into the current worktree using the top pull request:

```bash
gh stack checkout <top-pr>
gh stack view --json
```

The JSON view must show the expected stack and every pull request in bottom-to-top order. Then verify the branch relationship independently:

```bash
gh pr view <bottom-pr> --json number,headRefName,baseRefName,url
gh pr view <next-pr> --json number,headRefName,baseRefName,url
gh pr view <top-pr> --json number,headRefName,baseRefName,url
```

For a stack with more layers, run the same check for every pull request. Each `baseRefName` must equal the `headRefName` of the layer immediately below it, and the bottom pull request must target the stack trunk, normally `main`.

Do not consider the stack formally verified if the branch bases are correct but `gh stack view --json` does not show the formal stack. Run `gh stack link` with the complete bottom-to-top sequence, import it with `gh stack checkout <top-pr>`, and repeat both verification checks.

## Command side effects and recovery

| Command | Effect | Approval boundary |
| --- | --- | --- |
| `gh stack view --json` | Reads local stack state. | Read-only verification. |
| `gh pr view` | Reads pull request metadata. | Read-only verification. |
| `gh stack init`, `add` | Changes local stack tracking and branches. | Confirm the intended worktree and clean-state impact. |
| `gh stack checkout` | Fetches a remote stack when needed and changes local checkout/tracking. | Confirm local changes are safe to switch. |
| `gh stack link` | Creates or updates formal stack metadata; branch arguments can push and create pull requests. | Review inputs and intended remote changes first. |
| `gh stack submit` | Pushes branches and creates or updates pull requests and formal stack metadata. | Review the complete stack before submitting. |
| `gh stack push` | Pushes active stack branches and can use force-with-lease. | Explicit approval is required for rewritten remote history. |
| `gh stack sync` | Fetches, reconciles, rebases, and pushes the stack; it can use force-with-lease and atomic updates. | Explicit approval is required before running it. |
| `gh stack rebase` | Rewrites local stack commits while cascading branches upward. | Resolve the resulting history change before any push. |
| `gh stack merge` | Merges one or more stacked pull requests. | Explicit approval is required; do not use unconditional `--yes` in ordinary implementation work. |

If `gh stack rebase` stops on conflicts, resolve and stage the files, then run:

```bash
gh stack rebase --continue
```

To restore the pre-rebase state instead, run:

```bash
gh stack rebase --abort
```

## Verification checklist

Before reporting a stack as ready, confirm all of the following:

- The stack layers were identified bottom-to-top.
- One implementation pull request contains each top-level OpenSpec task group and all of its subtasks.
- Existing pull requests were formally linked with `gh stack link`, or `gh stack submit` created the formal stack.
- `gh stack checkout <top-pr>` imported or selected the remote stack locally.
- `gh stack view --json` shows the expected formal stack and order.
- `gh pr view` confirms every pull request targets its immediate parent branch.
- Any rebase, force-with-lease push, or merge has the required explicit approval.

## Official references

- [About stacked pull requests](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs)
- [Quickstart for stacked pull requests](https://docs.github.com/en/pull-requests/get-started/stacked-prs-quickstart)
- [Stacked pull requests CLI commands](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands)
