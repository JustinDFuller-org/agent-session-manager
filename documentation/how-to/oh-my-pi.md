---
layout: doc
title: Oh My Pi
description: Enable Oh My Pi and create a compatible Agent Session Manager pane.
diataxis_type: how-to
permalink: /documentation/user-guide/oh-my-pi/
---

## Before you start

Install Oh My Pi and make `omp` available from the interactive shell selected in **Settings → Panes → Terminal**. Agent Session Manager supports versions 17.2.11 through the 17.x series; version 18 and later are not supported. Enable **Oh My Pi** in **Settings → Harnesses**.

## Create an Oh My Pi pane

1. Open **New Pane** in a tab.
2. Select **Oh My Pi** under **Harness**.
3. Enter a session, branch, or worktree name.
4. Open **CLI Options** to choose supported Oh My Pi options. Use environment variables for provider credentials rather than adding secrets to options.
5. Choose **Create Pane**.

Agent Session Manager checks the installed version before creating the pane. If it reports an error, update Oh My Pi or correct the selected shell's PATH; the sheet remains open and no worktree or pane is created.

## Continue a session

Enable **Continue on Restart** in **Settings → Panes** to resume an available saved Oh My Pi session after an app restart. A quick refresh uses the same saved session. An explicit session option, such as `--resume` or `--continue`, takes precedence over automatic continuation.

## Use Agent Control

Enable Agent Control in the pane's advanced settings to let Oh My Pi discover Agent Session Manager's local control server. The pane uses the same control toggle as the other supported harnesses; no token needs to be copied into an option or profile.

## Related tasks

- [Supported Tools]({{ '/documentation/reference/supported-tools/' | relative_url }})
- [Tool Options]({{ '/documentation/user-guide/tool-options/' | relative_url }})
- [Continue After Restart]({{ '/documentation/user-guide/continue-after-restart/' | relative_url }})
- [Status Line]({{ '/documentation/user-guide/status-line/' | relative_url }})
