---
layout: doc
title: GitHub Pull Requests
description: Show pull-request status and receive attention when a tracked pull request changes state.
permalink: /documentation/user-guide/github-pull-requests/
---

## What it is

GitHub pull-request tracking finds the pull request for a pane's current Git branch and can show its status in the pane's status line. It can also notify you when a tracked pull request is merged or closed without merging.

## Why you might use it

Track build and review progress without leaving the pane where you are working.

## Before you start

Install the GitHub CLI (`gh`) and authenticate it. The pane must use a Git branch with a GitHub pull request.

## How to use it

### Show pull-request status

1. Open **Settings → Status Line**.
2. In **GitHub PR Tracking**, enable **Track pull requests**.
3. Add **PR** to a status-line row with **Add Item**.

The **PR** item shows the pull-request number and state when a pull request is found for the pane's current branch.

### Configure state notifications

1. Open **Settings → Notifications**.
2. In **GitHub PR**, enable **PR Merged Notifications** or **PR Closed Notifications**.
3. Keep **Banner Notifications** enabled if you also want macOS banners.

When a tracked pull request changes to merged or closed, the app can add a sidebar notification and show a macOS banner. Selecting the notification opens the related pane and presents the available action prompt.

## What you should see

The status line shows the **PR** item when tracking finds a pull request. The pull-request state can also be opened from the status-line item for more information.

## If it does not work

- Confirm that `gh` is installed and authenticated.
- Confirm that **Track pull requests** is enabled and that **PR** is in a status-line row.
- Confirm that the pane's current branch has a GitHub pull request.
- If banners do not appear, allow notifications for Agent Session Manager in **System Settings → Notifications**.

## Related tasks

- [Status Line]({{ '/documentation/user-guide/status-line/' | relative_url }})
- [Notifications]({{ '/documentation/user-guide/notifications/' | relative_url }})
- [Project Isolation]({{ '/documentation/user-guide/project-isolation/' | relative_url }})
