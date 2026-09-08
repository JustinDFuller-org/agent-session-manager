import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { scanPullRequestDescription, scanRepository } from "./fixed-width-prose.mjs";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const workflowPath = path.join(repositoryRoot, ".github/workflows/no-fixed-width-prose.yml");

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "fixed-width-prose-workflow-"));
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

test("workflow defines the stable fail-closed pull-request check", () => {
  const workflow = fs.readFileSync(workflowPath, "utf8");

  assert.match(workflow, /^name: Fixed-width Prose$/m);
  assert.match(workflow, /pull_request_target:/);
  for (const event of ["opened", "edited", "synchronize", "reopened", "ready_for_review", "converted_to_draft"]) {
    assert.match(workflow, new RegExp(`\\b${event}\\b`));
  }
  assert.match(workflow, /permissions: \{\}/);
  assert.match(workflow, /no-fixed-width-prose:\n    name: no-fixed-width-prose/);
  assert.doesNotMatch(workflow, /if:.*draft/i);
  assert.doesNotMatch(workflow, /IS_DRAFT|continue-on-error|stack.*relax/i);
});

test("workflow separates protected enforcement source from immutable candidate", () => {
  const workflow = fs.readFileSync(workflowPath, "utf8");

  assert.match(workflow, /path: enforcement-source/);
  assert.match(workflow, /github\.event\.repository\.default_branch/);
  assert.match(workflow, /path: candidate/);
  assert.match(workflow, /pull_request\.head\.sha/);
  assert.match(workflow, /cp enforcement-source\/.github\/scripts\/fixed-width-prose\.mjs/);
  assert.match(workflow, /node "\$RUNNER_TEMP\/fixed-width-prose\.mjs"/);
  assert.doesNotMatch(workflow, /node .*candidate\/\.github\/scripts\/fixed-width-prose/);
});

test("workflow passes the trusted pull-request description to the protected validator", () => {
  const workflow = fs.readFileSync(workflowPath, "utf8");

  assert.match(workflow, /PR_BODY: \$\{\{ github\.event\.pull_request\.body \|\| '' \}\}/);
  assert.match(workflow, /pull-request-description\.md/);
  assert.match(workflow, /--pull-request-description-file/);
});

test("base-owned scanning catches candidate Markdown violations", () => {
  const root = fixture();
  write(root, "README.md", "Candidate paragraph.\nCandidate continuation.\n");
  write(root, ".github/scripts/fixed-width-prose.mjs", "process.exitCode = 0\n");
  track(root);

  const findings = scanRepository(root);
  assert.deepEqual(findings.map(({ source, line }) => ({ source, line })), [
    { source: "README.md", line: 2 },
  ]);
});

test("base-owned scanning catches wrapped pull-request descriptions", () => {
  const findings = scanPullRequestDescription("PR paragraph.\nPR continuation.\n");
  assert.deepEqual(findings.map(({ sourceChannel, line }) => ({ sourceChannel, line })), [
    { sourceChannel: "pull-request-description", line: 2 },
  ]);
});
