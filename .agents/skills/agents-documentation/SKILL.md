---
name: agents-documentation
description: AGENTS.md and Agent Skills official doc index — load when implementing AGENTS.md support, creating or updating SKILL.md files, integrating agent skills into a client, validating skills with skills-ref, or working with the agentskills.io specification.
allowed-tools: WebFetch(domain:agents.md), WebFetch(domain:agentskills.io), WebFetch(domain:github.com)
metadata:
  user-invocable: "false"
---

# AGENTS.md & Agent Skills Documentation Index

Fetch from this index before implementing any AGENTS.md or Agent Skills feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://agentskills.io/llms.txt` — Complete index of all agentskills.io doc pages; fetch when you need a URL not listed here.

## AGENTS.md Format

- `http://agents.md/` — Complete AGENTS.md reference: format overview, why it exists, supported platforms, usage examples, and FAQ.

## Agent Skills — Specification

- `https://agentskills.io/specification` — Full SKILL.md format spec: frontmatter fields, directory structure, progressive disclosure, body conventions.
- `https://agentskills.io/` — Overview: what Agent Skills are, why they matter, how they work, which clients support them.

## Agent Skills — Skill Creation

- `https://agentskills.io/skill-creation/quickstart.md` — Getting started: creating your first SKILL.md with a step-by-step example.
- `https://agentskills.io/skill-creation/best-practices.md` — Best practices: scope, context budget, calibrating control, keeping skills focused.
- `https://agentskills.io/skill-creation/optimizing-descriptions.md` — Description tuning: how to test and iterate on the `description` field for reliable triggering.
- `https://agentskills.io/skill-creation/evaluating-skills.md` — Evaluation: writing test cases, running evals, grading outputs, iterating on skill quality.
- `https://agentskills.io/skill-creation/using-scripts.md` — Scripts: one-off commands, bundling scripts, error handling, dependency declarations for agentic use.

## Agent Skills — Client Integration

- `https://agentskills.io/client-implementation/adding-skills-support.md` — Adding skills support to an agent/tool: discovery, parsing, disclosure, activation, context management.
- `https://agentskills.io/clients.md` — Client showcase: 50+ tools that support Agent Skills with setup instructions and source links.

## skills-ref — Validation & Tooling

- `https://github.com/agentskills/agentskills/tree/main/skills-ref` — `skills-ref` reference library: install, CLI commands (`validate`, `read-properties`, `to-prompt`), Python API, and the `<available_skills>` XML format used in agent system prompts.
  - `skills-ref validate path/to/skill` — validate a skill directory against the spec
  - `skills-ref read-properties path/to/skill` — output skill frontmatter as JSON
  - `skills-ref to-prompt path/to/skill-a path/to/skill-b` — generate `<available_skills>` XML block for an agent system prompt
