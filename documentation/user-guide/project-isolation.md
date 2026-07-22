---
layout: doc
title: Project Isolation
description: Choose the branch or working copy for each agent task.
permalink: /documentation/user-guide/project-isolation/
---

## What it is

Agent Session Manager gives each agent pane a task working copy. This keeps changes for separate tasks from being mixed together in one checkout.

## Why you might use it

Use a separate working copy when you want several agents to work on different branches or tasks at the same time. You can also open an existing checkout when the task already has a working copy.

## Before you start

Create a tab for the Git repository you want to work in. Decide whether the pane should create a new task working copy or open an existing branch, ref, or worktree.

## How to use it

### Start a new task

1. Open **New Pane**.
2. In **Session, branch, or worktree**, enter a simple task name such as `feature-a`.
3. Choose **Create Pane**.

When the name does not match an existing checkout or ref, Agent Session Manager creates a separate working copy using the configured starting branch.

### Open an existing branch or worktree

1. Open **New Pane**.
2. Enter an existing branch, ref such as `origin/feature`, or worktree name.
3. Choose **Create Pane**.
4. If the checkout is already outside the app-managed locations, choose whether to open it without management or allow Agent Session Manager to manage it for cleanup.

### Choose a starting branch

For one tab, enter a branch in **Base Branch** when creating the tab. For the default behavior across new panes, open **Settings → Panes → New Pane**, enable **Default Branch**, and choose the branch name and **Starting Point**.

## What you should see

The pane opens in the selected working copy, and the agent tool starts there. Other panes can use different task working copies while remaining in the same tab.

## If it does not work

- If the entered name is rejected, use only letters, digits, dots, underscores, and dashes for a new task name.
- If you are opening a branch or ref, enter its full ref when needed, such as `origin/feature`.
- If a checkout is already open, close the other pane or use the existing pane instead of opening a duplicate task.
- If a new name cannot be resolved, check **Settings → Panes → New Pane → Default Branch**.

## Related tasks

- [Tabs and Panes](tabs-and-panes/)
- [Continue After Restart](continue-after-restart/)
- [Worktree Cleanup](worktree-cleanup/)
