import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  archiveGuidance,
  inspectCandidate,
  resolveCandidateTarget,
  stackContext,
  validateCandidate,
} from "./openspec-merge-gate.mjs";

function fixture() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "openspec-merge-gate-"));
}

function write(root, relativePath, content = "") {
  const filePath = path.join(root, relativePath);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

function archivedChange(root, name = "2026-09-06-example") {
  const prefix = `openspec/changes/archive/${name}`;
  write(root, `${prefix}/.openspec.yaml`, "schema: spec-driven\n");
  write(root, `${prefix}/proposal.md`, "## Why\nA durable requirement record.\n");
  write(root, `${prefix}/design.md`, "## Context\nA protected merge gate.\n");
  write(root, `${prefix}/tasks.md`, "## Tasks\n\n- [x] 1.1 Complete the gate\n");
  write(root, `${prefix}/specs/example/spec.md`, "## ADDED Requirements\n\n### Requirement: Example\nThe system SHALL validate.\n\n#### Scenario: Valid\n- **WHEN** checked\n- **THEN** it passes\n");
  write(root, "openspec/specs/example/spec.md", "## Purpose\nA durable main specification for the archived change.\n");
}

test("fails when the candidate has no OpenSpec change", () => {
  const root = fixture();
  const result = validateCandidate(root, {}, { runCli: false });
  assert.match(result.findings.join("\n"), /No OpenSpec change/);
});

test("fails active, incomplete, and skip_specs changes", () => {
  const root = fixture();
  write(root, "openspec/changes/example/.openspec.yaml", "schema: spec-driven\nskip_specs: true\n");
  write(root, "openspec/changes/example/proposal.md", "proposal\n");
  write(root, "openspec/changes/example/design.md", "design\n");
  write(root, "openspec/changes/example/tasks.md", "- [ ] 1.1 Finish\n");
  write(root, "openspec/changes/example/specs/example/spec.md", "spec\n");
  const result = validateCandidate(root, {}, { runCli: false });
  const findings = result.findings.join("\n");
  assert.match(findings, /Active OpenSpec change/);
  assert.match(findings, /skip_specs/);
  assert.match(findings, /0\/1 tasks complete/);
});

test("fails malformed archived changes and missing main specs", () => {
  const root = fixture();
  write(root, "openspec/changes/archive/2026-09-06-example/proposal.md", "proposal\n");
  const result = validateCandidate(root, {}, { runCli: false });
  const findings = result.findings.join("\n");
  assert.match(findings, /missing \.openspec\.yaml/);
  assert.match(findings, /missing design\.md/);
  assert.match(findings, /missing tasks\.md/);
  assert.match(findings, /no corresponding main specification/);
});

test("fails an archived delta without its matching main specification", () => {
  const root = fixture();
  const prefix = "openspec/changes/archive/2026-09-06-example";
  write(root, `${prefix}/.openspec.yaml`, "schema: spec-driven\n");
  write(root, `${prefix}/proposal.md`, "proposal\n");
  write(root, `${prefix}/design.md`, "design\n");
  write(root, `${prefix}/tasks.md`, "- [x] 1.1 Complete\n");
  write(root, `${prefix}/specs/missing/spec.md`, "delta\n");
  write(root, "openspec/specs/other/spec.md", "main\n");
  const result = validateCandidate(root, {}, { runCli: false });
  assert.match(result.findings.join("\n"), /openspec\/specs\/missing\/spec\.md/);
});

test("passes a complete archived change", () => {
  const root = fixture();
  archivedChange(root);
  const result = validateCandidate(root, {}, { runCli: false });
  assert.deepEqual(result.findings, []);
});

test("CLI validation catches malformed archived specifications", () => {
  const root = fixture();
  archivedChange(root);
  write(root, "openspec/changes/archive/2026-09-06-example/specs/example/spec.md", "This is not a requirement document.\n");
  const result = validateCandidate(root);
  assert.ok(result.findings.some((finding) => finding.includes("validate")));
});

test("inspects the complete candidate tree assembled across commits", () => {
  const root = fixture();
  archivedChange(root);
  write(root, "implementation/first-layer.txt", "first layer\n");
  write(root, "implementation/second-layer.txt", "second layer\n");
  const result = validateCandidate(root, {}, { runCli: false });
  assert.deepEqual(result.findings, []);
});

test("draft state does not relax strict findings", () => {
  const root = fixture();
  write(root, "openspec/changes/example/.openspec.yaml", "schema: spec-driven\n");
  const draft = validateCandidate(root, { IS_DRAFT: "true" }, { runCli: false });
  const ready = validateCandidate(root, { IS_DRAFT: "false" }, { runCli: false });
  assert.deepEqual(draft.findings, ready.findings);
});

test("higher stack layers are told not to archive", () => {
  const environment = {
    STACK_BASE_REF: "main",
    STACK_POSITION: "2",
    PR_BASE_REF: "feat-require-openspec",
  };
  assert.equal(stackContext(environment).kind, "higher");
  assert.match(archiveGuidance(environment), /Do not archive/);
  assert.match(archiveGuidance(environment), /feat-require-openspec/);
});

test("base stack layer owns archive guidance", () => {
  const environment = {
    STACK_BASE_REF: "main",
    STACK_POSITION: "1",
    PR_BASE_REF: "main",
  };
  assert.equal(stackContext(environment).kind, "base");
  assert.match(archiveGuidance(environment), /base PR/);
  assert.doesNotMatch(archiveGuidance(environment), /Do not archive/);
});

test("malformed stack metadata stays strict", () => {
  const context = stackContext({ STACK_BASE_REF: "main", STACK_POSITION: "not-a-number", PR_BASE_REF: "feature" });
  assert.equal(context.kind, "unknown");
  assert.equal(context.strict, true);
});

test("pull request candidate uses head repository and immutable SHA", () => {
  assert.deepEqual(resolveCandidateTarget({
    name: "pull_request_target",
    pullRequest: { head: { repository: { fullName: "fork-owner/repo" }, sha: "abc123" } },
  }), { repository: "fork-owner/repo", ref: "abc123" });
  assert.throws(() => resolveCandidateTarget({ name: "pull_request_target", pullRequest: { head: {} } }), /immutable SHA/);
});

test("push candidate uses repository SHA", () => {
  assert.deepEqual(resolveCandidateTarget({ name: "push", repository: "owner/repo", sha: "def456" }), {
    repository: "owner/repo",
    ref: "def456",
  });
});
