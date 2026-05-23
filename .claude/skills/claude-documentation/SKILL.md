---
name: claude-documentation
description: Claude Code official doc index — load when building Claude Code features, hooks, status line integration, settings files, worktrees, or any Claude Code CLI behavior.
user-invocable: false
allowed-tools:
  - WebFetch(domain:code.claude.com)
---

# Claude Code Documentation Index

Fetch from this index rather than guessing at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://code.claude.com/docs/llms.txt` — Complete index of all doc pages; fetch when you need a URL not listed here.

## Core Reference

- `https://code.claude.com/docs/en/cli-reference` — CLI flags, startup arguments, `--worktree`, `--settings`, `--model`, non-interactive mode (`-p`).
- `https://code.claude.com/docs/en/settings` — All configurable settings, settings file locations and scopes (managed > local > project > user), worktree settings.
- `https://code.claude.com/docs/en/env-vars` — Environment variables; use when a behavior can be toggled by env var.
- `https://code.claude.com/docs/en/tools-reference` — All built-in tools (Read, Edit, Bash, WebFetch, Agent, etc.), permission rule syntax per tool, and tool behavior details.

## Extension Points

- `https://code.claude.com/docs/en/skills` — SKILL.md format, all frontmatter fields (`allowed-tools`, `user-invocable`, `disable-model-invocation`, `context`, `agent`), dynamic context injection, supporting files.
- `https://code.claude.com/docs/en/hooks` — Hook lifecycle reference: events (PreToolUse, PostToolUse, Stop, SessionStart, statusLine, WorktreeCreate…), handler types (command/HTTP/MCP/prompt/agent), full input/output JSON schemas.
- `https://code.claude.com/docs/en/statusline` — Status line setup: configuration, available data fields (model, cost, context %, worktree, effort, vim mode, rate limits…), example scripts.
- `https://code.claude.com/docs/en/plugins-reference` — Plugin component schemas for skills, agents, hooks, MCP servers, monitors, themes; CLI commands for plugin management.

## Permissions & Security

- `https://code.claude.com/docs/en/permissions` — Permission rules (`allow`/`ask`/`deny`), all permission modes, Bash/WebFetch/Read/Edit rule syntax, working directories, managed settings.
- `https://code.claude.com/docs/en/model-config` — Model aliases (`opus`, `sonnet`, `opusplan`), effort levels, extended thinking, extended context, model-switching via flag/env/settings.

## Session & Interaction

- `https://code.claude.com/docs/en/commands` — All built-in `/commands` and bundled skills (`/loop`, `/batch`, `/code-review`, `/debug`) available in a session.
- `https://code.claude.com/docs/en/interactive-mode` — Keyboard shortcuts, vim editor mode, shell mode (`!` prefix), task list, PR review status, session recap.
- `https://code.claude.com/docs/en/keybindings` — Customizing keybindings: contexts, all action names, chord syntax, unbinding defaults.
- `https://code.claude.com/docs/en/terminal-config` — Terminal setup: Shift+Enter, Option-as-Meta on macOS, tmux passthrough, fullscreen rendering, vim mode.

## Parallel Workflows

- `https://code.claude.com/docs/en/worktrees` — `--worktree` flag, subagent isolation, `.worktreeinclude` for copying gitignored files, WorktreeCreate/WorktreeRemove hooks, cleanup.

## Context & Memory

- `https://code.claude.com/docs/en/memory` — CLAUDE.md files (project/user/managed), auto memory, `.claude/rules/` with path-scoped frontmatter.
- `https://code.claude.com/docs/en/glossary` — Definitions: agentic loop, compaction, hook, skill, subagent, worktree isolation, session, tool, permission mode, etc.
