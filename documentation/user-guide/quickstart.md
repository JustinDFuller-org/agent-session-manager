---
layout: doc
title: Quickstart
description: Open a project, create a tab, and start your first agent pane.
permalink: /documentation/user-guide/quickstart/
---

## What it is

This walkthrough takes you from the main window to a running agent session in a project directory.

## Before you start

Complete [Install and First Launch](install/) and make sure at least one agent tool is active in **Settings → Harnesses**. Use a Git repository for the project directory.

## How to use it

1. Open Agent Session Manager and press ⌘T, or choose **File → New Tab**.
2. In **New Tab**, enter a project name in **Name**.
3. Choose the project directory with **Choose…**. The directory should contain the Git repository where you want to work.
4. Optionally enter a starting branch in **Base Branch**.
5. Choose **Create**. The new tab becomes active.
6. Press ⌘P, or choose **File → New Pane in Current Tab**.
7. In **New Pane**, select an active tool in **Harness**.
8. Enter a session name, branch, or worktree in **Session, branch, or worktree**. For a new task, use a simple name such as `feature-a`.
9. Review any **CLI Options** or **Environment Variables** shown for the selected tool, then choose **Create Pane**.

## What you should see

Agent Session Manager prepares the working copy and opens a pane for the selected tool. The pane contains the tool's terminal session, and the tab remains available for creating additional panes.

## If it does not work

- If **Create** is disabled in **New Tab**, provide both a name and a directory.
- If no tool appears in **Harness**, enable one in **Settings → Harnesses**.
- If the pane cannot resolve the entered name or branch, check the spelling and use an existing branch, ref, or worktree name.

## Related tasks

- [Core Concepts](core-concepts/)
- [Tabs and Panes](tabs-and-panes/)
- [Agent Tools](agent-tools/)
- [Project Isolation](project-isolation/)
- [Overview](overview/)
- [Install and First Launch](install/)
