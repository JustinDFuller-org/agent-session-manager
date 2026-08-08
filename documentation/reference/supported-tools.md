---
layout: doc
title: Supported Tools
description: The agent tools that Agent Session Manager can detect, configure, and launch in panes.
permalink: /documentation/reference/supported-tools/
diataxis_type: reference
---

Agent Session Manager supports these agent tools in panes:

| Tool | Enable it in | Pane guide |
| --- | --- | --- |
| Claude Code | **Settings → Harnesses → Claude Code** | [Claude Code]({{ '/documentation/user-guide/claude-code/' | relative_url }}) |
| Codex | **Settings → Harnesses → Codex** | [Codex]({{ '/documentation/user-guide/codex/' | relative_url }}) |
| Cursor | **Settings → Harnesses → Cursor** | [Cursor]({{ '/documentation/user-guide/cursor/' | relative_url }}) |
| OpenCode | **Settings → Harnesses → OpenCode** | [OpenCode]({{ '/documentation/user-guide/opencode/' | relative_url }}) |
| Oh My Pi | **Settings → Harnesses → Oh My Pi** | [Oh My Pi]({{ '/documentation/user-guide/oh-my-pi/' | relative_url }}) |

## Common support

Every supported tool can:

- run in a pane after its command is available in the selected shell;
- use the shared session, branch, or worktree flow;
- use a profile when the profile targets that tool;
- receive tool-specific CLI options from the New Pane sheet; and
- show app-owned information such as the worktree, branch, session duration,
  changed lines, and pull-request status when those values are available.

Tool-specific options and status information vary by tool. Use the
tool-specific guide for setup steps and the relevant how-to guide for
configuration.

## Related documentation

- [Agent Tools]({{ '/documentation/user-guide/agent-tools/' | relative_url }})
- [Tool Options]({{ '/documentation/user-guide/tool-options/' | relative_url }})
- [Profiles]({{ '/documentation/user-guide/profiles/' | relative_url }})
- [Project Isolation]({{ '/documentation/user-guide/project-isolation/' | relative_url }})
