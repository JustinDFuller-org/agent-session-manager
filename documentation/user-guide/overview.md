---
layout: doc
title: Overview
description: Understand what Agent Session Manager does and whether it fits your workflow.
permalink: /documentation/user-guide/overview/
---

## What it is

Agent Session Manager is a native macOS app for running multiple AI agent sessions in parallel. A tab represents a project directory, and each pane is a separate terminal session inside that tab.

Each pane can run Claude Code, Cursor, Codex, or OpenCode. The app starts the selected tool in a Git working copy so separate tasks can stay organized.

## Why you might use it

Use Agent Session Manager when you want to work on several agent tasks without switching between separate terminal windows. Keep related sessions together in a tab, compare their progress, and focus on one pane when you need more room.

## Before you start

You need a Mac running macOS 14 or later. To start an agent pane, you also need a supported agent tool available in the shell that Agent Session Manager uses and a Git repository to work in.

## What you should see

After launch, the main window provides a tab bar and a pane area. When no tab is open, the empty state tells you to press ⌘T to create one.

![Agent Session Manager showing a tab with two panes]({{ '/assets/img/docs/split-panes.png' | relative_url }})

_The main window keeps related agent sessions together in one tab._

## Related tasks

- [Install and First Launch](install/)
- [Quickstart](quickstart/)
- [Core Concepts](core-concepts/)
