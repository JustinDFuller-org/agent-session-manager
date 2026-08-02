---
layout: doc
title: Overview
description: Manage and keep track of many simultaneous AI agent sessions from one macOS window.
diataxis_type: explanation
permalink: /documentation/user-guide/overview/
---

## What Agent Session Manager is

Agent Session Manager is a native macOS app for running multiple AI agent
sessions in parallel. It keeps related sessions in one window while
preserving a separate project and task context for each session.

## How the product fits together

A **tab** represents a project directory. Each **pane** is one terminal session
inside that tab. A pane can run Claude Code, Cursor, Codex, OpenCode, or a
shell opened from another pane.

Agent panes use Git worktrees for task isolation. A worktree is a separate
working directory linked to the same repository, so one task's files and
branch can stay separate from another task's files and branch.

The result is a workflow with a fixed outer shape—project tab, task pane,
terminal session—while the tool, model, options, profile, and workflow inside
each pane remain configurable.

## Why this model is useful

Several agent sessions are easier to supervise when their activity, status
information, notifications, and pull-request updates are visible in one
window. Tabs separate projects; panes separate tasks within a project.

![Agent Session Manager showing two panes in one tab]({{ '/assets/img/docs/split-panes.png' | relative_url }})

_A tab keeps related agent sessions together while each pane retains its own
task context._

## Read next

- Learn the terms in [Core Concepts]({{ '/documentation/user-guide/core-concepts/' | relative_url }}).
- Complete the [Quickstart]({{ '/documentation/user-guide/quickstart/' | relative_url }}).
- See [Supported Tools]({{ '/documentation/reference/supported-tools/' | relative_url }}) for the factual tool list.
- Follow [Install and First Launch]({{ '/documentation/user-guide/install/' | relative_url }}) when you are ready to begin.
