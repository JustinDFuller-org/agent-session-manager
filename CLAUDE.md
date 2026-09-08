# Documentation guidance

Use `.agents/skills/diataxis-documentation` before creating, editing, moving, or reviewing documentation.

For the optional OpenSpec `opsx` workflow, see [`openspec/README.md`](openspec/README.md).

## Required approach

- Classify each public page as a tutorial, how-to guide, reference, or explanation before editing it.
- Keep one dominant user need per page. Split mixed content and link between the resulting pages.
- Verify public claims against the current UI, source, tests, or canonical internal feature documentation.
- Keep implementation, persistence, telemetry, diagnostic, release, and agent-only material out of the public Jekyll site.
- Preserve existing public permalinks unless the change includes a deliberate redirect strategy.
- Update navigation, related links, inventories, screenshots, and rendered site checks when documentation moves.
- Use exact visible labels and explain product terms at first use.
- Write `Agent Session Manager` in full; do not use the acronym `ASM`.

Public documentation lives under:

- `documentation/tutorials/`
- `documentation/how-to/`
- `documentation/reference/`
- `documentation/explanation/`

Run `make docs-check` and `scripts/test-release-publishing.sh` before finishing documentation work. Do not use fabricated application state for documentation screenshots.
