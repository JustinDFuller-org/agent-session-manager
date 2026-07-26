---
layout: doc
title: Core Concepts
description: Learn how tabs, panes, agent tools, branches, and Git worktrees fit together.
permalink: /documentation/user-guide/core-concepts/
---

## What it is

Agent Session Manager uses a small set of concepts to organize parallel work.

### Tab

A tab represents a project directory. It is the context that contains the panes for one project.

### Pane

A pane is one terminal session inside a tab. It runs an agent tool or, when opened from an existing pane, a shell in that pane's working directory.

### Agent tool

An agent tool is the command-line program that works inside a pane. Agent Session Manager currently supports Claude Code, Cursor, Codex, and OpenCode. Only tools enabled in **Settings → Harnesses** appear when you create a pane.

### Repository

A repository is the project directory and Git history that a tab represents. The directory selected in **New Tab** must contain the Git repository where you want to work.

### Branch

A branch is a named line of development. A branch points to commits in the repository history; it is not the same thing as the directory containing the files.

### Git worktree

A Git worktree is an independent working directory linked to the same repository. Each agent pane runs in one worktree, so several panes can work on different branches without mixing their files.

Agent Session Manager creates linked worktrees for new tasks and can also open an existing worktree. Closing or deleting a managed worktree removes that working directory, but does not delete its branch or commits.

### Session name, branch, or worktree

The **Session, branch, or worktree** field in **New Pane** chooses the Git worktree for the pane. For a new task, enter a simple task name such as `feature-a`; when a starting branch is configured, Agent Session Manager creates a new branch and Git worktree with that name. You can also enter an existing local branch, a remote branch such as `origin/feature`, or an existing worktree name.

## Why you might use these concepts

Tabs keep repositories separate. Panes keep task worktrees separate within a repository. Agent tools determine which command-line assistant runs, while the task name or branch identifies the work associated with that pane.

## What you should see

The main window shows tabs across the top and panes below them. Creating another pane adds another terminal session to the active tab; switching tabs changes the project context and its panes.

![Agent Session Manager main window with an active tab]({{ '/assets/img/docs/main-window-tab.png' | relative_url }})

_A tab identifies the project context shown below the tab bar._

## Related tasks

- [Quickstart]({{ '/documentation/user-guide/quickstart/' | relative_url }})
- [Tabs and Panes]({{ '/documentation/user-guide/tabs-and-panes/' | relative_url }})
- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Project Isolation]({{ '/documentation/user-guide/project-isolation/' | relative_url }})
- [Overview]({{ '/documentation/user-guide/overview/' | relative_url }})
- [Install and First Launch]({{ '/documentation/user-guide/install/' | relative_url }})
