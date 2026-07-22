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

## Related tasks

- [Quickstart](quickstart/)
- [Overview](overview/)
- [Install and First Launch](install/)
