---
layout: doc
title: Core Concepts
description: Learn how tabs, panes, agent tools, sessions, and working copies fit together.
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

### Session name, branch, or worktree

The **Session, branch, or worktree** field in **New Pane** identifies the task's working copy. You can enter a session name, an existing branch or ref, or the name of an existing worktree.

### Separate working copy

When Agent Session Manager creates a new task workspace, it uses a separate Git working copy for that pane. This lets multiple panes work on different tasks without making every task use the same checkout.

## Why you might use these concepts

Tabs keep projects separate. Panes keep tasks within a project separate. Agent tools determine which command-line assistant runs, while the session or branch name identifies the work associated with that pane.

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
