---
layout: doc
title: Terminal Scrollback
description: Choose how much terminal output remains available to scroll back through.
permalink: /documentation/user-guide/terminal-scrollback/
---

## What it is

Terminal scrollback keeps output that has moved above the visible terminal area so you can review earlier agent output.

## Why you might use it

Increase the buffer for long-running tasks whose output you may need to inspect later.

## Before you start

Open **Settings → Panes → Terminal**.

## How to use it

1. Find **Scrollback Lines**.
2. Enter a value from 100 to 1,000,000.
3. Leave the setting in place; it is saved for future launches.

The setting applies immediately to open terminal panes. Values outside the supported range are clamped to the nearest limit.

![Agent Session Manager terminal settings]({{ '/assets/img/docs/settings-panes.png' | relative_url }})

_Scrollback Lines appears in Settings → Panes → Terminal._

## What you should see

You can scroll farther back through terminal output when the buffer is larger.

## If it does not work

- If the value is adjusted, enter a whole number between 100 and 1,000,000.
- If older output is unavailable, increase **Scrollback Lines** before the output scrolls out of the buffer.

## Related tasks

- [Tabs and Panes]({{ '/documentation/user-guide/tabs-and-panes/' | relative_url }})
- [Troubleshooting]({{ '/documentation/user-guide/troubleshooting/' | relative_url }})
