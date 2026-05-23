---
name: cursor-documentation
description: Cursor official doc index — load when building Cursor features, CLI integration, hooks, rules, skills, MCP, worktrees, or any Cursor agent behavior.
user-invocable: false
allowed-tools:
  - WebFetch(domain:cursor.com)
---

# Cursor Documentation Index

Fetch from this index before implementing any Cursor feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://cursor.com/llms.txt` — Complete sitemap of all Cursor doc pages; fetch when you need a URL not listed here.

## Core Reference

- `https://cursor.com/en/docs/get-started/cli` — CLI overview: installation, basics, and getting started.
- `https://cursor.com/en/docs/advanced/cli` — CLI usage: how to invoke Cursor from the terminal.
- `https://cursor.com/en/docs/reference/cli` — CLI reference: all flags, parameters, and options.
- `https://cursor.com/en/docs/reference/configuration` — Configuration reference: settings file format and all configurable options.

## Extension Points

- `https://cursor.com/en/docs/extensions/plugins` — Plugin system: how plugins extend Cursor.
- `https://cursor.com/en/docs/extensions/rules` — Rules: `.cursorrules` and project/user rules for customizing agent behavior.
- `https://cursor.com/en/docs/extensions/skills` — Skills: defining reusable skills for the agent.
- `https://cursor.com/en/docs/extensions/subagents` — Subagents: spawning and coordinating sub-agents.
- `https://cursor.com/en/docs/extensions/hooks` — Hooks: lifecycle events and hook handler configuration.
- `https://cursor.com/en/docs/extensions/mcp` — MCP: Model Context Protocol server integration.

## Permissions & Security

- `https://cursor.com/en/docs/reference/permissions` — Permission rules: allow/ask/deny syntax, tool permissions, working directory restrictions.
- `https://cursor.com/en/docs/reference/authentication` — Authentication: API keys, auth methods, and credential management.

## Session & Interaction

- `https://cursor.com/en/docs/reference/slash-commands` — Slash commands: all built-in `/commands` available in a session.
- `https://cursor.com/en/docs/advanced/shell-mode` — Shell mode: using the `!` prefix and shell integration.

## Parallel Workflows

- `https://cursor.com/en/docs/configuration/worktrees` — Worktrees: parallel session isolation, worktree creation, and multi-branch workflows.

## Agent Tools

- `https://cursor.com/en/docs/agent/tools/terminal` — Terminal tool: how the agent uses the terminal, permissions, and invocation.

## Index

- `https://cursor.com/en-US/docs` — Main documentation hub; browse for topics not listed above.
