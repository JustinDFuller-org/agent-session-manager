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

const DEFAULT_CHANGE = "2026-09-07-example";

function fixture() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "openspec-merge-gate-"));
}

function write(root, relativePath, content = "content\n") {
  const filePath = path.join(root, relativePath);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

function changeRoot(root, name, archived) {
  return path.join(root, "openspec", "changes", ...(archived ? ["archive"] : []), name);
}

function writeChange(root, name = DEFAULT_CHANGE, { archived = false, complete = true } = {}) {
  const prefix = path.relative(root, changeRoot(root, name, archived));
  write(root, `${prefix}/.openspec.yaml`, "schema: spec-driven\n");
  write(root, `${prefix}/proposal.md`, "## Why\nA durable requirement record.\n");
  write(root, `${prefix}/design.md`, "## Context\nA protected merge gate.\n");
  write(root, `${prefix}/tasks.md`, `## Tasks\n\n- [${complete ? "x" : " "}] 1.1 Complete the gate\n`);
  write(root, `${prefix}/specs/${name}.md`, "## ADDED Requirements\n\n### Requirement: Example\nThe system SHALL validate.\n\n#### Scenario: Valid\n- **WHEN** checked\n- **THEN** it passes\n");
  if (archived) write(root, `openspec/specs/${name}.md`, "## Purpose\nA durable main specification.\n");
}

function activeChange(root, name = DEFAULT_CHANGE, complete = true) {
  writeChange(root, name, { complete });
}

function archiveChange(root, name = DEFAULT_CHANGE, complete = true) {
  writeChange(root, name, { archived: true, complete });
}

function createSnapshot({ active = [], archived = [], incomplete = [], archivedIncomplete = [] } = {}) {
  const root = fixture();
  for (const name of active) activeChange(root, name, !incomplete.includes(name));
  for (const name of archived) archiveChange(root, name, !archivedIncomplete.includes(name));
  return root;
}

function fileManifest(root) {
  const files = [];
  function visit(directory, relativeDirectory = "") {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const relativePath = path.posix.join(relativeDirectory, entry.name);
      const entryPath = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(entryPath, relativePath);
      else if (entry.isFile()) files.push(relativePath);
    }
  }
  visit(root);
  return files.sort();
}

function trustedSnapshots({ trunk = {}, immediateBase = {}, candidate = {} } = {}) {
  const snapshots = {
    trunk: createSnapshot(trunk),
    immediateBase: createSnapshot(immediateBase),
    candidate: createSnapshot(candidate),
  };
  return {
    ...snapshots,
    manifests: Object.fromEntries(Object.entries(snapshots).map(([name, root]) => [name, fileManifest(root)])),
  };
}

function datedArchiveChange(root, changeName = "example", archiveName = "2026-09-07-example", complete = true) {
  const source = fixture();
  activeChange(source, changeName, complete);
  for (const relativePath of [
    `.openspec.yaml`,
    "proposal.md",
    "design.md",
    "tasks.md",
    `specs/${changeName}.md`,
  ]) {
    write(root, `openspec/changes/archive/${archiveName}/${relativePath}`, fs.readFileSync(path.join(source, `openspec/changes/${changeName}/${relativePath}`), "utf8"));
  }
  write(root, `openspec/specs/${changeName}.md`, "## Purpose\nA durable main specification.\n");
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

function stackEnvironment(position, size, overrides = {}) {
  return prEnvironment({
    PR_BASE_REF: position === 1 ? "main" : `layer-${position - 1}`,
    STACK_POSITION: String(position),
    STACK_SIZE: String(size),
    ...overrides,
  });
}

function standaloneEnvironment(overrides = {}) {
  return {
    EVENT_NAME: "pull_request_target",
    PR_BASE_REF: "main",
    STACK_PRESENT: "false",
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
  assert.equal(stackContext(stackEnvironment(1, 4)).kind, "non-top");
  assert.equal(stackContext(stackEnvironment(4, 4)).kind, "top");
  assert.equal(stackContext(stackEnvironment(3, 2)).kind, "unknown");
  assert.equal(stackContext(stackEnvironment(1, 2, { STACK_BASE_REF: "release" })).kind, "unknown");
  assert.match(archiveGuidance(stackEnvironment(2, 4)), /Continue implementation or QA/);
  assert.match(archiveGuidance(stackEnvironment(4, 4)), /archive-only/);
});

test("fails closed when formal stack metadata is incomplete", () => {
  assert.equal(stackContext(stackEnvironment(1, 2, { STACK_BASE_SHA: "" })).kind, "unknown");
  assert.equal(stackContext(stackEnvironment(1, 2, { STACK_POSITION: "one" })).kind, "unknown");
  assert.equal(stackContext(stackEnvironment(1, 2, { STACK_PRESENT: "false", STACK_BASE_REF: "main" })).kind, "unknown");
  assert.equal(stackContext(stackEnvironment(1, 2, { STACK_PRESENT: "maybe" })).kind, "unknown");
  assert.equal(stackContext({ PR_BASE_REF: "" }).kind, "unknown");
});

test("builds deterministic initial and partially collapsed trusted snapshots", () => {
  const initial = trustedSnapshots({
    trunk: {},
    immediateBase: { active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] },
    candidate: { active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] },
  });
  const collapsed = trustedSnapshots({
    trunk: { active: [DEFAULT_CHANGE] },
    immediateBase: { active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] },
    candidate: { active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] },
  });

  assert.deepEqual(initial.manifests.trunk, []);
  assert.ok(initial.manifests.immediateBase.includes(`openspec/changes/${DEFAULT_CHANGE}/tasks.md`));
  assert.ok(collapsed.manifests.trunk.includes(`openspec/changes/${DEFAULT_CHANGE}/tasks.md`));
  assert.ok(collapsed.manifests.candidate.includes(`openspec/changes/${DEFAULT_CHANGE}/tasks.md`));
});

test("accepts a non-top active change with incomplete tasks", () => {
  const snapshots = trustedSnapshots({
    trunk: {},
    immediateBase: { active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] },
    candidate: { active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] },
  });
  const result = validate(snapshots.candidate, snapshots.immediateBase, snapshots.trunk, stackEnvironment(2, 4));
  assert.deepEqual(result.findings, []);
});

test("requires archival only at the current top of a four-layer stack", () => {
  const trunk = createSnapshot();
  for (const position of [1, 2, 3]) {
    const immediateBase = createSnapshot(position === 1 ? {} : { active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] });
    const candidate = createSnapshot({ active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] });
    const result = validate(candidate, immediateBase, trunk, stackEnvironment(position, 4));
    assert.deepEqual(result.findings, [], `position ${position} should remain a continuation layer`);
  }

  const immediateBase = createSnapshot({ active: [DEFAULT_CHANGE] });
  const candidate = createSnapshot({ archived: [DEFAULT_CHANGE] });
  const result = validate(candidate, immediateBase, trunk, stackEnvironment(4, 4));
  assert.deepEqual(result.findings, []);
});

test("supports standalone and formal one-layer finalization without a minimum stack size", () => {
  const trunk = createSnapshot();
  const immediateBase = createSnapshot();
  const candidate = createSnapshot({ archived: ["new-change"] });

  assert.deepEqual(validate(candidate, immediateBase, trunk, standaloneEnvironment()).findings, []);
  assert.deepEqual(validate(candidate, immediateBase, trunk, stackEnvironment(1, 1)).findings, []);
});

test("follows finalization ownership as a stack collapses from four layers to one", () => {
  const trunk = createSnapshot({ active: [DEFAULT_CHANGE] });
  const immediateBase = createSnapshot({ active: [DEFAULT_CHANGE] });
  const archiveCandidate = createSnapshot({ archived: [DEFAULT_CHANGE] });
  const activeCandidate = createSnapshot({ active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] });

  for (const size of [4, 3, 2, 1]) {
    const topResult = validate(archiveCandidate, immediateBase, trunk, stackEnvironment(size, size));
    assert.deepEqual(topResult.findings, [], `position ${size} of ${size} should finalize`);
    assert.equal(topResult.stack.position, size);
    assert.equal(topResult.stack.size, size);
  }

  for (const size of [4, 3, 2]) {
    const continuationResult = validate(activeCandidate, immediateBase, trunk, stackEnvironment(1, size));
    assert.deepEqual(continuationResult.findings, [], `position 1 of ${size} should continue`);
    assert.equal(continuationResult.stack.kind, "non-top");
  }
});

test("accepts the dated archive directory produced by OpenSpec for the shared change", () => {
  const trunk = fixture();
  const immediateBase = fixture();
  const candidate = fixture();
  activeChange(immediateBase, "example");
  datedArchiveChange(candidate);
  const result = validate(candidate, immediateBase, trunk, prEnvironment({ STACK_POSITION: "2", STACK_SIZE: "2", PR_BASE_REF: "layer-1" }));
  assert.deepEqual(result.findings, []);
});

test("accepts an active-to-archived handoff after main temporarily carries the active change", () => {
  const snapshots = trustedSnapshots({
    trunk: { active: [DEFAULT_CHANGE] },
    immediateBase: { active: [DEFAULT_CHANGE] },
    candidate: { archived: [DEFAULT_CHANGE] },
  });
  const result = validate(snapshots.candidate, snapshots.immediateBase, snapshots.trunk, stackEnvironment(2, 2, { PR_BASE_REF: "main" }));
  assert.deepEqual(result.findings, []);
});

test("rejects inherited historical archives as new changes", () => {
  const trunk = createSnapshot({ archived: [DEFAULT_CHANGE] });
  const immediateBase = createSnapshot();
  const candidate = createSnapshot({ archived: [DEFAULT_CHANGE] });
  const result = validate(candidate, immediateBase, trunk, standaloneEnvironment());
  assert.match(result.findings.join("\n"), /new archived OpenSpec change|absent from the trunk/);
});

test("rejects bottom layers that reuse active or archived trunk names", () => {
  const activeTrunk = createSnapshot({ active: ["already-active"] });
  const activeCandidate = createSnapshot({ active: ["already-active"] });
  const activeResult = validate(activeCandidate, createSnapshot(), activeTrunk, stackEnvironment(1, 2));
  assert.match(activeResult.findings.join("\n"), /already present on the trunk/);

  const archivedTrunk = createSnapshot({ archived: ["already-archived"] });
  const archivedCandidate = createSnapshot({ active: ["already-archived"] });
  const archivedResult = validate(archivedCandidate, createSnapshot(), archivedTrunk, stackEnvironment(1, 2));
  assert.match(archivedResult.findings.join("\n"), /reuses archived change/);
});

test("rejects archiving an active change already present on the trunk as new", () => {
  const trunk = createSnapshot({ active: ["already-active"] });
  const candidate = createSnapshot({ archived: ["already-active"] });
  const result = validate(candidate, createSnapshot(), trunk, standaloneEnvironment());
  assert.match(result.findings.join("\n"), /active change\(s\) already present on the trunk/);
});

test("rejects omitted or competing names on a higher layer", () => {
  const trunk = createSnapshot();
  const immediateBase = createSnapshot({ active: ["shared-change"] });
  const omitted = createSnapshot({ active: ["other-change"] });
  const competing = createSnapshot({ active: ["shared-change", "other-change"] });

  const omittedResult = validate(omitted, immediateBase, trunk, stackEnvironment(2, 3));
  assert.match(omittedResult.findings.join("\n"), /change-set mismatch/);
  const competingResult = validate(competing, immediateBase, trunk, stackEnvironment(2, 3));
  assert.match(competingResult.findings.join("\n"), /change-set mismatch/);
});

test("rejects a non-top layer that archives early", () => {
  const immediateBase = createSnapshot({ active: [DEFAULT_CHANGE] });
  const candidate = createSnapshot({ archived: [DEFAULT_CHANGE] });
  const result = validate(candidate, immediateBase, createSnapshot(), stackEnvironment(2, 4));
  assert.match(result.findings.join("\n"), /change-set mismatch|changed an archived OpenSpec path/);
  assert.match(result.findings.join("\n"), /Only the current top layer archives it/);
});

test("requires the current top to archive and complete the shared change", () => {
  const immediateBase = createSnapshot({ active: [DEFAULT_CHANGE] });
  const incompleteCandidate = createSnapshot({ active: [DEFAULT_CHANGE], incomplete: [DEFAULT_CHANGE] });
  const incomplete = validate(incompleteCandidate, immediateBase, createSnapshot(), stackEnvironment(4, 4));
  assert.match(incomplete.findings.join("\n"), /must not retain active|incomplete/);

  const completeCandidate = createSnapshot({ archived: [DEFAULT_CHANGE] });
  const complete = validate(completeCandidate, immediateBase, createSnapshot(), stackEnvironment(4, 4));
  assert.deepEqual(complete.findings, []);
});

test("requires archive-only top diffs", () => {
  const immediateBase = createSnapshot({ active: [DEFAULT_CHANGE] });
  const candidate = createSnapshot({ archived: [DEFAULT_CHANGE] });
  write(candidate, "Sources/Unexpected.swift", "implementation\n");
  const result = validate(candidate, immediateBase, createSnapshot(), stackEnvironment(2, 2));
  assert.match(result.findings.join("\n"), /unexpected changed path 'Sources\/Unexpected.swift'/);

  write(candidate, "documentation/unrelated.md", "documentation\n");
  const mixedResult = validate(candidate, immediateBase, createSnapshot(), stackEnvironment(2, 2));
  assert.match(mixedResult.findings.join("\n"), /unexpected changed path 'documentation\/unrelated.md'/);
});

test("supports a standalone archive and reports exact changed paths", () => {
  const immediateBase = createSnapshot();
  const candidate = createSnapshot({ archived: ["new-change"] });
  const result = validate(candidate, immediateBase, createSnapshot(), standaloneEnvironment());
  assert.deepEqual(result.findings, []);
  assert.ok(changedPaths(immediateBase, candidate).includes("openspec/changes/archive/new-change/specs/new-change.md"));
  assert.ok(changedPaths(immediateBase, candidate).includes("openspec/specs/new-change.md"));
});

test("rejects malformed artifacts, missing main specs, and skip_specs", () => {
  const missingMetadata = createSnapshot({ active: [DEFAULT_CHANGE] });
  fs.rmSync(path.join(changeRoot(missingMetadata, DEFAULT_CHANGE, false), ".openspec.yaml"));
  const missingMetadataResult = validate(missingMetadata, createSnapshot(), createSnapshot(), standaloneEnvironment());
  assert.match(missingMetadataResult.findings.join("\n"), /missing \.openspec\.yaml/);

  const skipSpecs = createSnapshot({ active: [DEFAULT_CHANGE] });
  write(skipSpecs, `openspec/changes/${DEFAULT_CHANGE}/.openspec.yaml`, "schema: spec-driven\nskip_specs: true\n");
  const skipSpecsResult = validate(skipSpecs, createSnapshot(), createSnapshot(), standaloneEnvironment());
  assert.match(skipSpecsResult.findings.join("\n"), /skip_specs: true/);

  const missingDelta = createSnapshot({ active: [DEFAULT_CHANGE] });
  fs.rmSync(path.join(changeRoot(missingDelta, DEFAULT_CHANGE, false), "specs"), { recursive: true });
  const missingDeltaResult = validate(missingDelta, createSnapshot(), createSnapshot(), standaloneEnvironment());
  assert.match(missingDeltaResult.findings.join("\n"), /missing a delta specification/);

  const missingMainSpec = createSnapshot({ archived: [DEFAULT_CHANGE] });
  fs.rmSync(path.join(missingMainSpec, "openspec", "specs", `${DEFAULT_CHANGE}.md`));
  const missingMainSpecResult = validate(missingMainSpec, createSnapshot(), createSnapshot(), standaloneEnvironment());
  assert.match(missingMainSpecResult.findings.join("\n"), /missing corresponding main specification/);
});

test("rejects incomplete archived tasks at the finalization layer", () => {
  const candidate = createSnapshot({ archived: [DEFAULT_CHANGE], archivedIncomplete: [DEFAULT_CHANGE] });
  const result = validate(candidate, createSnapshot(), createSnapshot(), standaloneEnvironment());
  assert.match(result.findings.join("\n"), /checklist incomplete/);
});

test("keeps strict CLI validation and base-owned enforcement in the workflow", () => {
  const validator = fs.readFileSync(new URL("./openspec-merge-gate.mjs", import.meta.url), "utf8");
  const workflow = fs.readFileSync(new URL("../workflows/openspec.yml", import.meta.url), "utf8");
  assert.match(validator, /\["validate", "--archived", "--no-interactive"\]/);
  assert.match(validator, /\["validate", "--all", "--strict", "--no-interactive"\]/);
  assert.match(workflow, /workflow_call:/);
  assert.doesNotMatch(workflow, /pull_request_target:\n/);
  assert.match(workflow, /ref: \$\{\{ github\.event\.repository\.default_branch \}\}/);
  assert.match(workflow, /node --test enforcement-source\/\.github\/scripts\/openspec-merge-gate\.test\.mjs enforcement-source\/\.github\/scripts\/ci-gate-guidance\.test\.mjs/);
  assert.match(workflow, /github\.event\.pull_request\.head\.sha/);
  assert.match(workflow, /STACK_POSITION:/);
  assert.doesNotMatch(workflow, /candidate\/\.github\/scripts\/openspec-merge-gate\.mjs/);
});

test("resolves immutable candidates for same-repository and fork pull requests", () => {
  assert.deepEqual(resolveCandidateTarget({
    name: "pull_request_target",
    pullRequest: { head: { repository: { fullName: "fork-owner/repo" }, sha: "abc123" } },
  }), { repository: "fork-owner/repo", ref: "abc123" });
  assert.deepEqual(resolveCandidateTarget({
    name: "pull_request_target",
    pullRequest: { head: { repository: { fullName: "JustinDFuller/agent-session-manager" }, sha: "def456" } },
  }), { repository: "JustinDFuller/agent-session-manager", ref: "def456" });
  assert.deepEqual(resolveCandidateTarget({
    name: "push",
    repository: "JustinDFuller/agent-session-manager",
    sha: "ghi789",
  }), { repository: "JustinDFuller/agent-session-manager", ref: "ghi789" });
  assert.throws(() => resolveCandidateTarget({ name: "pull_request_target", pullRequest: { head: {} } }), /immutable SHA/);
  assert.throws(() => resolveCandidateTarget({ name: "push", repository: "repo" }), /immutable SHA/);
});
