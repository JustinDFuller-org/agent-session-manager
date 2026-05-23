---
name: git-worktree-documentation
description: Git worktree official doc index — load when building git worktree features, worktree creation, listing, removal, locking, pruning, repair, or any git worktree CLI behavior.
user-invocable: false
allowed-tools:
  - WebFetch(domain:git-scm.com)
---

# Git Worktree Documentation Index

Fetch from this index before implementing any git worktree feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://git-scm.com/docs` — Main git reference page; complete list of all commands and guides.

## Core Worktree

- `https://git-scm.com/docs/git-worktree` — Main worktree manual; all subcommands (add, list, lock, move, prune, remove, repair, unlock), options, refs, config, porcelain and default output formats.

## Configuration

- `https://git-scm.com/docs/git-config` — Git configuration; `extensions.worktreeConfig`, `worktree.guessRemote`, `worktree.useRelativePaths`, `checkout.defaultRemote`, `gc.worktreePruneExpire`.

## Repository Layout & Internals

- `https://git-scm.com/docs/gitrepository-layout` — Repository layout; `$GIT_DIR/worktrees/` directory structure, `gitdir` file, `locked` file, `config.worktree`.
- `https://git-scm.com/docs/gitglossary` — Glossary; definitions for HEAD, worktree, bare repository, detached HEAD.
- `https://git-scm.com/docs/gitrevisions` — Revisions syntax; specifying commits, branches, and refs for worktree creation.

## Branching & Checkout

- `https://git-scm.com/docs/git-branch` — Branch management; `-b`/`-B` flags, `--track`, listing branches, upstream tracking.
- `https://git-scm.com/docs/git-checkout` — Checkout; DETACHED HEAD mode, branch switching.
- `https://git-scm.com/docs/git-switch` — Switch branches; modern alternative to checkout.

## Refs & Path Resolution

- `https://git-scm.com/docs/git-rev-parse` — Rev-parse; `--git-path` for worktree path resolution, ref access across worktrees, `main-worktree/` and `worktrees/` ref paths.
- `https://git-scm.com/docs/git-update-ref` — Update-ref; per-worktree ref updates.
- `https://git-scm.com/docs/git-symbolic-ref` — Symbolic-ref; reading/setting HEAD.
- `https://git-scm.com/docs/git-for-each-ref` — For-each-ref; iterating refs across worktrees.
- `https://git-scm.com/docs/git-show-ref` — Show-ref; listing refs.

## Repository Lifecycle

- `https://git-scm.com/docs/git-init` — Init; creating repositories, main worktree creation.
- `https://git-scm.com/docs/git-clone` — Clone; cloning repositories, main worktree creation.
- `https://git-scm.com/docs/git` — Main git command; overview and global options.

## Maintenance & Cleanup

- `https://git-scm.com/docs/git-gc` — Garbage collection; `gc.worktreePruneExpire`, automatic pruning of stale worktree metadata.
- `https://git-scm.com/docs/git-clean` — Clean; removing untracked files (relevant for worktree remove pre-check).
- `https://git-scm.com/docs/git-fsck` — Filesystem check; repository integrity validation.

## State Inspection

- `https://git-scm.com/docs/git-status` — Status; checking worktree cleanliness with porcelain output format.
- `https://git-scm.com/docs/git-log` — Log; branch/commit history inspection.
- `https://git-scm.com/docs/git-stash` — Stash; temporary work storage as alternative to worktrees.
- `https://git-scm.com/docs/git-diff` — Diff; checking tracked file modifications in a worktree.

## Remote Interaction

- `https://git-scm.com/docs/git-remote` — Remote; remote tracking configuration for branch disambiguation.
- `https://git-scm.com/docs/git-fetch` — Fetch; fetching remote branches before worktree creation.

## Submodules

- `https://git-scm.com/docs/git-submodule` — Submodule; worktree limitations with submodules.

## Hooks & Automation

- `https://git-scm.com/docs/githooks` — Hooks; repository-level hooks relevant for agent worktree creation/removal workflows.

## Guides

- `https://git-scm.com/docs/gitworkflows` — Workflows; multi-branch workflow patterns.
- `https://git-scm.com/docs/gitcli` — CLI conventions; understanding git CLI patterns, option syntax, and porcelain output conventions.

## Plumbing (Output Parsing)

- `https://git-scm.com/docs/git-ls-files` — Ls-files; index inspection for worktree state.
- `https://git-scm.com/docs/git-read-tree` — Read-tree; sparse checkout integration with worktrees.
- `https://git-scm.com/docs/git-rev-list` — Rev-list; commit listing for worktree branch inspection.

## Other Commands

- `https://git-scm.com/docs/git-reset` — Reset; resetting worktree HEAD state.
- `https://git-scm.com/docs/git-merge` — Merge; branch merging.
- `https://git-scm.com/docs/git-reflog` — Reflog; reference history logs.
