---
name: no-code-comments
description: "Apply the repository's strict no-code-comments policy and use the approved explanation channels."
---

# No-code-comments policy

Do not add explanatory comments to tracked source, test, script, build, CI, hook, or configuration files. This includes line comments, block comments, documentation comments, section markers, `MARK:` labels, shellcheck annotations, and inline comments.

Use the appropriate durable channel instead:

- Explain why a change is needed in the pull-request description.
- Record change history in commit titles and messages.
- Explain how to use a feature in the user-facing documentation site or an agent skill.
- If code is confusing, simplify and clarify it first. If the remaining rationale is important, put it in the pull-request description.
- Explain the purpose of a package in the nearest `README.md` or the relevant feature map.

Markdown files, pull-request prose, and commit messages are allowed to contain prose. Executable shebangs and the first-line `// swift-tools-version: ...` directive in `Package.swift` are machine directives and remain allowed.

Comment-like text inside strings, URLs, raw or multiline strings, embedded scripts, heredocs, generated values, and CSS colors is data rather than a code comment.

## Local validation

Run the repository-wide check from the repository root:

```bash
make no-code-comments
```

The checker scans all tracked files in the candidate tree and reports each violation as `path:line:column`. It is intentionally separate from Swift format and SwiftLint.

## Stacked change workflow

The no-code-comments work is delivered in four layers:

1. Spec: OpenSpec proposal, requirements, design, and tasks.
2. Implementation: validator, tests, local command, protected workflow, and guidance.
3. Migration: remove all existing in-scope comments without changing behavior.
4. QA: record full validation and verify failing and passing temporary pull requests.

The Spec PR owns OpenSpec completion and archiving. Higher layers must not archive or create a competing change.
