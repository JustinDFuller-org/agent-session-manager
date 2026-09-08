---
name: fixed-width-prose
description: Prevent fixed-width hard-wrapped prose in Markdown files and pull-request descriptions, and provide strong authoring guidance for commit bodies. Use when writing or reviewing Markdown, pull-request descriptions, commit messages, agent guidance, or repository documentation.
---

# Fixed-width prose

Use this skill whenever you write or review Markdown files, pull-request descriptions, commit bodies, agent guidance, or repository documentation.

## Authoring rule

Keep each logical paragraph, list item, blockquote paragraph, and pull-request description paragraph on one physical line so the renderer can wrap it naturally.

Do not insert a physical line break inside a sentence or paragraph merely to keep text within a preferred column width.

Commit bodies should follow the same rule as strong guidance, but they are not a hard CI input because force-pushes are prohibited and a pushed message cannot be removed from the pull request's commit set without rewriting history.

## Structural exceptions

The rule does not apply to fenced code, indented code, tables, YAML front matter, headings, thematic breaks, raw HTML blocks, or separate one-line list items.

Keep each structural construct valid for its format; the validator preserves these line-oriented structures instead of treating them as prose paragraphs.

## Validation

Run the local check before review:

```bash
make no-fixed-width-prose
```

The check scans every tracked Markdown-family file and reports repository-relative source, line, column, and reason diagnostics.

CI will fail for any finding in tracked Markdown-family files or the current pull-request description, including drafts and every formal stacked pull-request layer.

Do not force-push to bypass or repair a failure; fix the affected file or pull-request description in a new commit and rerun the check.

## Migration guidance

When cleaning existing content, join wrapped prose lines within each logical paragraph, list item, or blockquote paragraph while preserving blank paragraph boundaries and structural Markdown.

Review fenced code, tables, front matter, headings, thematic breaks, raw HTML, links, and list structure after reflowing a file.

Use the dedicated migration stack layer for repository-wide cleanup; do not add an automatic fixer to CI.
