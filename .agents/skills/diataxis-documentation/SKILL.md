---
name: diataxis-documentation
description: Classify, write, review, and reorganize Agent Session Manager documentation using the Diátaxis framework. Use when changing public guides, internal documentation boundaries, navigation, documentation metadata, screenshots, or documentation quality checks.
---

# Diátaxis documentation

Use the Diátaxis framework to match documentation to the user's immediate need. Read the local authoring reference before making a substantial documentation change:

See [references/authoring-guide.md](references/authoring-guide.md).

## Classify before writing

Choose one dominant documentation type using the Diátaxis compass:

| The page informs... | The user is... | Type |
| --- | --- | --- |
| Action | Acquiring skill | Tutorial |
| Action | Applying skill | How-to guide |
| Cognition | Applying skill | Reference |
| Cognition | Acquiring skill | Explanation |

Use the official [Diátaxis primer](https://diataxis.fr/start-here/) and [compass](https://diataxis.fr/compass/) when the boundary is unclear.

Do not make one page serve multiple types merely by adding headings. Split material when the reader's goal, assumed knowledge, or writing obligation changes. Link to the other type instead.

## Repository rules

- Public pages belong under `documentation/tutorials/`, `documentation/how-to/`, `documentation/reference/`, or `documentation/explanation/`.
- Internal feature, architecture, diagnostic, release, and agent guidance remains outside the public Jekyll output.
- Preserve an existing public `permalink` unless a redirect strategy is explicitly part of the change.
- Verify public claims against current source, visible UI labels, tests, or canonical internal feature documentation.
- Explain product terms at first use; do not expose implementation paths, persistence schemas, telemetry details, or test-only controls in public guides.
- Do not use the acronym `ASM`; write `Agent Session Manager`.
- Use only real-flow screenshots with descriptive alt text and captions.
- Update `_data/navigation.yml`, related links, inventories, and publication checks when pages move or change type.

## Review before finishing

1. Confirm the page has one `diataxis_type` value.
2. Check that its title and opening sentence match the selected type.
3. Remove content that belongs in another type and add a useful link instead.
4. Check exact UI labels and current supported-tool claims.
5. Run `make docs-check` and `scripts/test-release-publishing.sh`.
6. Validate this skill with `skills-ref validate .agents/skills/diataxis-documentation` when the validator is available.
