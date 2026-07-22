---
layout: doc
title: Status Line
description: Customize the information shown at the bottom of each terminal pane.
permalink: /documentation/user-guide/status-line/
---

## What it is

The status line is the information bar at the bottom of a pane. It can show session details, model and usage information, duration, working-copy changes, and other facts available for the selected tool.

## Why you might use it

Choose the information that helps you scan several panes quickly without interrupting the terminal session.

## Before you start

Open **Settings** and select **Status Line**. Some facts are available only for particular agent tools, so the available choices can change with the selected harness or pane.

## How to use it

1. Open **Settings → Status Line**.
2. Choose the display style, item alignment, and percentage display options in **Display**.
3. Add or remove rows with **Add Row** and the row controls.
4. Within a row, choose **Add Item** and select the facts you want to see.
5. Use the up and down controls to reorder rows and the minus controls to remove items.
6. Optionally choose **Add Custom Field** to run a command that supplies a value for the status line.
7. Changes are saved as you edit the layout.

Facts that are not supported by a pane’s harness are omitted. A supported fact with no current value may show a dash until data is available.

### Show pull-request status

In **GitHub PR Tracking**, enable **Track pull requests** to show the current pull request status for a pane’s Git branch. This requires the GitHub CLI (`gh`) to be installed and authenticated. The same section controls polling and background refresh.

## What you should see

The configured rows appear at the bottom of each applicable terminal pane. The order in Settings matches the order in the pane, and custom fields refresh according to their configured interval.

![Agent Session Manager Status Line settings]({{ '/assets/img/docs/settings-status-line.png' | relative_url }})

_Status Line settings control the layout and pull-request tracking options._

![Agent Session Manager pane with a status line]({{ '/assets/img/docs/pane-status-indicators.png' | relative_url }})

_A pane status line displays the configured facts below the terminal._

## If it does not work

- If an item is missing from **Add Item**, it may not be supported for the selected harness or may already be in a row.
- If the status line is not visible, add at least one row and one item in **Settings → Status Line**.
- If a custom field does not produce a value, use its preview in the editor and check the command, refresh interval, and timeout.
- If pull-request status is missing, confirm that `gh` is installed, authenticated, and that **Track pull requests** is enabled.

## Related tasks

- [Profiles]({{ '/documentation/user-guide/profiles/' | relative_url }})
- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Tool Options]({{ '/documentation/user-guide/tool-options/' | relative_url }})
