---
name: feature-recursive-development
description: "Run safe, isolated Dev validation for agent-driven recursive development."
---

# Recursive development validation

Read `documentation/features/recursive-development.md` before using this workflow.

After focused tests/builds for a user-visible runtime change, start a fresh owned run with `scripts/recursive-development.sh start`. Verify branch, commit, and exact title before operating the UI. Use Computer Use only after its plugin, Screen Recording, Accessibility, and calibration prerequisites are satisfied; inspect fresh state before every action and prefer accessibility elements. Exercise real controls, save only safe screenshots, enable Debug Mode through Settings when traces are required, run focused Dev XCTest, and use `profile` only for startup/rendering/concurrency/terminal concerns. Collect evidence, stop the verified owned PID, and report visual, functional, telemetry, invariants, automated tests, performance, and cleanup independently. Missing visual permission or evidence is unverified, never passed.

## Reusable visual scenario

For a compact real-flow visual check, use [the tab-and-pane calibration](references/tab-and-pane-calibration.md). It is a deliberately small template: copy it and change only the named UI outcome and evidence expectations for a later scenario. It is not a replacement for XCTest, a headless test runner, or permission to operate an unowned app.
