# Diátaxis authoring guide

This repository uses four documentation types. The type describes the reader's need, not the feature being documented.

## Tutorials

A tutorial is a practical lesson for someone learning the product. Keep one successful path in view, introduce terms before relying on them, and use checkpoints so the learner can tell whether they are on track. Prefer a complete first experience over a catalog of options.

Use a tutorial for the first successful Agent Session Manager session:

- State the learning goal.
- List only the prerequisites needed for the lesson.
- Give sequential actions with exact visible labels.
- Describe the result after each meaningful milestone.
- Link to how-to guides and reference pages for alternatives.

Do not turn a tutorial into a complete settings reference or troubleshooting catalog.

## How-to guides

A how-to guide helps an already-capable user complete a real task. State the goal and relevant prerequisites, then provide direct steps and recovery by symptom. It is acceptable to mention several supported options when they are needed to complete the task, but do not teach the entire product.

Good titles describe a task or outcome:

- Configure a profile for a recurring task
- Reopen a saved session after restarting
- Show pull-request status in a pane

## Reference

Reference documentation is neutral, factual, and complete enough to consult while working. Organize it around the structure of the product or its configuration. Prefer tables, exact labels, accepted values, availability, and concise definitions. Avoid motivation, narrative, and step-by-step instructions except where needed to interpret a fact.

The keyboard-shortcut and supported-tool pages are public reference material. Implementation matrices, source maps, persistence schemas, and diagnostic catalogs remain internal references.

## Explanation

An explanation provides context, relationships, rationale, and tradeoffs. It answers why a behavior exists or how concepts fit together. It serves study, not immediate task execution. Link to a how-to guide for action and a reference page for exact facts.

Use explanations for the Agent Session Manager mental model, including the relationship between tabs, panes, sessions, branches, and Git worktrees.

## Migration checklist

Before changing a public page:

1. Read `AGENTS.md` and this skill.
2. Inspect the current UI labels, relevant source, tests, and internal feature documentation.
3. Decide the page type and add one `diataxis_type` front matter value.
4. Preserve the existing permalink unless redirects are included.
5. Keep public copy free of implementation-only details.
6. Update navigation and related-task links.
7. Check screenshots, alt text, and captions if the visible workflow changed.
8. Run `make docs-check` and `scripts/test-release-publishing.sh`.

When a page contains two different obligations, create separate pages rather than adding a second page type. Keep the internal source document when it records behavior needed by maintainers, agents, or incident diagnosis.
