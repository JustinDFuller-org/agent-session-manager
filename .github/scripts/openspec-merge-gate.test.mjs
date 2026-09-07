import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  archiveGuidance,
  changedPaths,
  resolveCandidateTarget,
  stackContext,
  validateCandidate,
} from "./openspec-merge-gate.mjs";

function fixture() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "openspec-merge-gate-"));
}

function write(root, relativePath, content = "content\n") {
  const filePath = path.join(root, relativePath);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

function activeChange(root, name = "2026-09-07-example", complete = true) {
  const prefix = `openspec/changes/${name}`;
  write(root, `${prefix}/.openspec.yaml`, "schema: spec-driven\n");
  write(root, `${prefix}/proposal.md`, "## Why\nA durable requirement record.\n");
  write(root, `${prefix}/design.md`, "## Context\nA protected merge gate.\n");
  write(root, `${prefix}/tasks.md`, `## Tasks\n\n- [${complete ? "x" : " "}] 1.1 Complete the gate\n`);
  write(root, `${prefix}/specs/example/spec.md`, "## ADDED Requirements\n\n### Requirement: Example\nThe system SHALL validate.\n\n#### Scenario: Valid\n- **WHEN** checked\n- **THEN** it passes\n");
}

function archiveChange(root, name = "2026-09-07-example", complete = true) {
  const source = fixture();
  activeChange(source, name, complete);
  for (const relativePath of [
    `.openspec.yaml`,
    "proposal.md",
    "design.md",
    "tasks.md",
    "specs/example/spec.md",
  ]) {
    write(root, `openspec/changes/archive/${name}/${relativePath}`, fs.readFileSync(path.join(source, `openspec/changes/${name}/${relativePath}`), "utf8"));
  }
  write(root, "openspec/specs/example/spec.md", "## Purpose\nA durable main specification.\n");
}

function prEnvironment(overrides = {}) {
  return {
    EVENT_NAME: "pull_request_target",
    PR_BASE_REF: "main",
    STACK_BASE_REF: "main",
    STACK_BASE_SHA: "trunk-sha",
    STACK_POSITION: "1",
    STACK_SIZE: "2",
    STACK_PRESENT: "true",
    DEFAULT_BRANCH: "main",
    ...overrides,
  };
}

function validate(candidate, immediateBase, trunk, environment) {
  return validateCandidate(candidate, environment, {
    immediateBaseDirectory: immediateBase,
    trunkDirectory: trunk,
    runCli: false,
  });
}

test("normalizes standalone, non-top, and current top stack context", () => {
  assert.equal(stackContext({ PR_BASE_REF: "main" }).kind, "standalone");
  assert.equal(stackContext(prEnvironment({ STACK_POSITION: "1", STACK_SIZE: "4" })).kind, "non-top");
  assert.equal(stackContext(prEnvironment({ STACK_POSITION: "4", STACK_SIZE: "4" })).kind, "top");
  assert.equal(stackContext(prEnvironment({ STACK_POSITION: "3", STACK_SIZE: "2" })).kind, "unknown");
  assert.equal(stackContext(prEnvironment({ STACK_BASE_REF: "release", STACK_POSITION: "1", STACK_SIZE: "2" })).kind, "unknown");
  assert.match(archiveGuidance(prEnvironment({ STACK_POSITION: "2", STACK_SIZE: "4" })), /Continue implementation or QA/);
});

test("fails closed when formal stack metadata is incomplete", () => {
  const context = stackContext(prEnvironment({ STACK_BASE_SHA: "" }));
  assert.equal(context.kind, "unknown");
});

test("accepts a non-top active change with incomplete tasks", () => {
  const trunk = fixture();
  const immediateBase = fixture();
  const candidate = fixture();
  activeChange(immediateBase, undefined, false);
  activeChange(candidate, undefined, false);
  const result = validate(candidate, immediateBase, trunk, prEnvironment({ STACK_POSITION: "2", STACK_SIZE: "4", PR_BASE_REF: "layer-1" }));
  assert.deepEqual(result.findings, []);
});

test("requires the current top to archive and complete the shared change", () => {
  const trunk = fixture();
  const immediateBase = fixture();
  const incompleteCandidate = fixture();
  const completeCandidate = fixture();
  activeChange(immediateBase, undefined, true);
  activeChange(incompleteCandidate, undefined, false);
  activeChange(completeCandidate, undefined, true);
  const incomplete = validate(incompleteCandidate, immediateBase, trunk, prEnvironment({ STACK_POSITION: "4", STACK_SIZE: "4", PR_BASE_REF: "layer-3" }));
  assert.match(incomplete.findings.join("\n"), /must not retain active|incomplete/);

  archiveChange(completeCandidate);
  fs.rmSync(path.join(completeCandidate, "openspec/changes/2026-09-07-example"), { recursive: true });
  const complete = validate(completeCandidate, immediateBase, trunk, prEnvironment({ STACK_POSITION: "4", STACK_SIZE: "4", PR_BASE_REF: "layer-3" }));
  assert.deepEqual(complete.findings, []);
});

test("accepts an active-to-archived handoff after main temporarily carries the active change", () => {
  const trunk = fixture();
  const immediateBase = fixture();
  const candidate = fixture();
  activeChange(immediateBase);
  archiveChange(candidate);
  const result = validate(candidate, immediateBase, trunk, prEnvironment({ STACK_POSITION: "2", STACK_SIZE: "2", PR_BASE_REF: "main" }));
  assert.deepEqual(result.findings, []);
});

test("rejects an inherited historical archive as a new change", () => {
  const trunk = fixture();
  const immediateBase = fixture();
  const candidate = fixture();
  archiveChange(trunk, "2026-09-07-example");
  archiveChange(candidate, "2026-09-07-example");
  const result = validate(candidate, immediateBase, trunk, prEnvironment({ STACK_PRESENT: "false", STACK_BASE_REF: "", STACK_BASE_SHA: "", STACK_POSITION: "", STACK_SIZE: "", PR_BASE_REF: "main" }));
  assert.match(result.findings.join("\n"), /new archived OpenSpec change|absent from the trunk/);
});

test("rejects omitted or competing names on a higher layer", () => {
  const trunk = fixture();
  const immediateBase = fixture();
  const omitted = fixture();
  const competing = fixture();
  activeChange(immediateBase, "shared-change");
  activeChange(omitted, "other-change");
  activeChange(competing, "shared-change");
  activeChange(competing, "other-change");
  const omittedResult = validate(omitted, immediateBase, trunk, prEnvironment({ STACK_POSITION: "2", STACK_SIZE: "3", PR_BASE_REF: "layer-1" }));
  assert.match(omittedResult.findings.join("\n"), /change-set mismatch/);
  const competingResult = validate(competing, immediateBase, trunk, prEnvironment({ STACK_POSITION: "2", STACK_SIZE: "3", PR_BASE_REF: "layer-1" }));
  assert.match(competingResult.findings.join("\n"), /change-set mismatch/);
});

test("requires archive-only top diffs", () => {
  const trunk = fixture();
  const immediateBase = fixture();
  const candidate = fixture();
  activeChange(immediateBase);
  archiveChange(candidate);
  write(candidate, "Sources/Unexpected.swift", "implementation\n");
  const result = validate(candidate, immediateBase, trunk, prEnvironment({ STACK_POSITION: "2", STACK_SIZE: "2", PR_BASE_REF: "main" }));
  assert.match(result.findings.join("\n"), /unexpected changed path 'Sources\/Unexpected.swift'/);
});

test("supports a standalone one-layer archive and reports exact changed paths", () => {
  const trunk = fixture();
  const immediateBase = fixture();
  const candidate = fixture();
  archiveChange(candidate, "new-change");
  const result = validate(candidate, immediateBase, trunk, {
    EVENT_NAME: "pull_request_target",
    PR_BASE_REF: "main",
    STACK_PRESENT: "false",
  });
  assert.deepEqual(result.findings, []);
  assert.ok(changedPaths(immediateBase, candidate).includes("openspec/changes/archive/new-change/tasks.md"));
});

test("resolves pull request candidates from the immutable head repository and SHA", () => {
  assert.deepEqual(resolveCandidateTarget({
    name: "pull_request_target",
    pullRequest: { head: { repository: { fullName: "fork-owner/repo" }, sha: "abc123" } },
  }), { repository: "fork-owner/repo", ref: "abc123" });
  assert.throws(() => resolveCandidateTarget({ name: "pull_request_target", pullRequest: { head: {} } }), /immutable SHA/);
});
