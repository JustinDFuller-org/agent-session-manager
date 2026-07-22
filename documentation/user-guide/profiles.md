---
layout: doc
title: Profiles
description: Save reusable agent tool settings and apply them when creating panes.
permalink: /documentation/user-guide/profiles/
---

## What it is

A profile is a named set of settings for one agent tool. It can include CLI options, environment variables for tools that support them, and an optional status line layout.

## Why you might use it

Profiles save repeated setup. Create one for a common model, permission mode, workflow, or status line, then apply it to a new pane instead of configuring each option again.

## Before you start

Enable the agent tool you want to use in [Agent Tools](agent-tools/). Profiles can only use active tools.

## How to use it

### Create or edit a profile

1. Open **Settings** and select **Profiles**.
2. Choose **New Profile**, or open an existing profile’s menu and choose **Edit**.
3. Enter a **Profile Name** and choose a **Harness**.
4. Enable the CLI options and environment variables the profile should apply.
5. Mark **Show on new pane** for options you want to adjust each time. Options that are not shown are still applied.
6. Optionally enable a custom status line for the profile.
7. Save the profile.

Use **Duplicate** to make a copy, **Delete** to remove a profile, or the up and down arrows to change its order.

### Apply a profile to a pane

1. Open **New Pane**.
2. Choose a profile from **Profile**.
3. Review any options displayed in the sheet.
4. Choose **Create Pane**.

The profile selects its harness and applies its saved settings. If you change an option, the profile name is marked **(modified)**. Choose **Save Profile & Create** if you want to save the changed settings before creating the pane.

The first profile in the list that matches the selected harness is preselected when a new pane opens.

## What you should see

The profile appears in **Settings → Profiles** and in the **Profile** picker in **New Pane**. Options marked **Show on new pane** appear for editing; other saved options remain hidden while they are applied.

## If it does not work

- If a profile does not appear in **New Pane**, enable its harness in [Agent Tools](agent-tools/).
- If an option is not visible, edit the profile and enable **Show on new pane** for that option.
- If the profile is not preselected, move it higher than other profiles for the same harness.

## Related tasks

- [Agent Tools](agent-tools/)
- [Tool Options](tool-options/)
- [Status Line](status-line/)
- [Tabs and Panes](tabs-and-panes/)
