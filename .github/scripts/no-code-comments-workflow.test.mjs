import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { scanRepository } from "./no-code-comments.mjs";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const workflowPath = path.join(repositoryRoot, ".github/workflows/no-code-comments.yml");
const validatorPath = path.join(repositoryRoot, ".github/scripts/no-code-comments.mjs");

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "no-code-comments-workflow-"));
  execFileSync("git", ["init", "--quiet", root]);
  return root;
}

function write(root, relativePath, content) {
  const filePath = path.join(root, relativePath);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

function track(root) {
  execFileSync("git", ["-C", root, "add", "."]);
}

function cleanCandidate(root) {
  write(root, "Sources/Clean.swift", "let value = 1\n");
  write(root, "README.md", "# Prose\n\n// Markdown data\n");
  write(root, "script.sh", "#!/bin/sh\nprintf '%s\\n' '# data'\n");
  write(root, "Package.swift", "// swift-tools-version: 6.1\nimport PackageDescription\n");
  track(root);
}

test("workflow defines reusable validation and main push coverage", () => {
  const workflow = fs.readFileSync(workflowPath, "utf8");

  assert.match(workflow, /^name: No Code Comments$/m);
  assert.match(workflow, /workflow_call:/);
  assert.match(workflow, /push:\n    branches: \[main\]/);
  assert.match(workflow, /permissions: \{\}/);
  assert.match(workflow, /no-code-comments:\n    name: no-code-comments/);
  assert.doesNotMatch(workflow, /if:.*draft/i);
  assert.doesNotMatch(workflow, /IS_DRAFT/);
  assert.doesNotMatch(workflow, /stack/i);
});

test("workflow separates protected enforcement source from immutable candidate", () => {
  const workflow = fs.readFileSync(workflowPath, "utf8");

  assert.match(workflow, /path: enforcement-source/);
  assert.match(workflow, /pull_request\.base\.sha/);
  assert.match(workflow, /path: candidate/);
  assert.match(workflow, /pull_request\.head\.sha/);
  assert.match(workflow, /cp enforcement-source\/.github\/scripts\/no-code-comments\.mjs/);
  assert.match(workflow, /node "\$RUNNER_TEMP\/no-code-comments\.mjs" --root "\$GITHUB_WORKSPACE\/candidate"/);
  assert.doesNotMatch(workflow, /node .*candidate\/\.github\/scripts/);
});

test("clean candidate passes the same scanner used by CI", () => {
  const root = fixture();
  cleanCandidate(root);
  write(root, ".github/workflows/removed.yml", "name: removed\n");
  track(root);
  fs.unlinkSync(path.join(root, ".github/workflows/removed.yml"));
  assert.deepEqual(scanRepository(root), []);
});

test("violating candidate fails with a repository-relative location", () => {
  const root = fixture();
  write(root, "Sources/Bad.swift", "let value = 1 // forbidden\n");
  track(root);

  const result = spawnSync(process.execPath, [validatorPath, "--root", root], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Sources\/Bad\.swift:1:15: line comment/);
});

test("candidate enforcement changes cannot bypass the protected scanner", () => {
  const root = fixture();
  write(root, ".github/scripts/no-code-comments.mjs", "process.exitCode = 0\n");
  write(root, ".github/workflows/no-code-comments.yml", "name: bypass\n");
  write(root, "Sources/Bad.swift", "let value = 1 // candidate violation\n");
  track(root);

  const findings = scanRepository(root);
  assert.deepEqual(findings.map(({ file, line, column, kind }) => ({ file, line, column, kind })), [
    { file: "Sources/Bad.swift", line: 1, column: 15, kind: "line comment" },
  ]);
});

test("a higher stack layer receives the same strict clean-candidate result", () => {
  const root = fixture();
  cleanCandidate(root);
  assert.deepEqual(scanRepository(root), []);
});
