---
layout: doc
title: Overview
description: Manage and keep track of many simultaneous AI agent sessions from one macOS window.
permalink: /documentation/user-guide/overview/
---

## What it is

Agent Session Manager is a native macOS app for running multiple AI agent sessions in parallel. A tab represents a project directory, and each pane is a separate terminal session inside that tab.

Each pane can run Claude Code, Cursor, Codex, or OpenCode. The app starts the selected tool in a Git working copy so separate tasks can stay organized.

## Why you might use it

Use Agent Session Manager when you have multiple agent sessions open at once. Keep them together in one window, track which tasks are active, and switch between sessions without hunting through separate terminal windows.

## Before you start

You need a Mac running macOS 14 or later. To start an agent pane, you also need a supported agent tool available in the shell that Agent Session Manager uses and a Git repository to work in.

## What you should see

After launch, the main window provides a tab bar and a pane area. When no tab is open, the empty state tells you to press ⌘T to create one.

![Agent Session Manager showing two panes in one tab]({{ '/assets/img/docs/split-panes.png' | relative_url }})

_The main window keeps related agent sessions together in one tab._

## Related tasks

- [Install and First Launch]({{ '/documentation/user-guide/install/' | relative_url }})
- [Quickstart]({{ '/documentation/user-guide/quickstart/' | relative_url }})
- [Core Concepts]({{ '/documentation/user-guide/core-concepts/' | relative_url }})
