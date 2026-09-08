import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {runGate} from "./ci-gate-workflow.mjs";

const repositoryRoot = path.resolve(new URL("../..", import.meta.url).pathname);
const workflow = fs.readFileSync(path.join(repositoryRoot, ".github/workflows/ci-gate.yml"), "utf8");
const runner = fs.readFileSync(path.join(repositoryRoot, ".github/scripts/ci-gate-workflow.mjs"), "utf8");

test("defines the base-owned pull-request gate lifecycle and stable job", () => {
  assert.match(workflow, /^name: CI Gate$/m);
  assert.match(workflow, /pull_request_target:/u);
  for (const event of ["opened", "edited", "synchronize", "reopened", "ready_for_review", "converted_to_draft"]) assert.match(workflow, new RegExp(`\\b${event}\\b`, "u"));
  assert.match(workflow, /permissions: \{\}/u);
  assert.match(workflow, /ci-gate:\n    name: ci-gate/u);
  assert.match(workflow, /timeout-minutes: 15/u);
  assert.match(workflow, /group: ci-gate-\$\{\{ github\.event\.pull_request\.number \}\}/u);
  assert.match(workflow, /cancel-in-progress: true/u);
});

test("checks out only immutable default-branch enforcement source", () => {
  assert.match(workflow, /ref: \$\{\{ github\.workflow_sha \}\}/u);
  assert.match(workflow, /CI_GATE_POLICY_SHA: \$\{\{ github\.workflow_sha \}\}/u);
  assert.doesNotMatch(workflow, /github\.event\.repository\.default_branch|github\.sha \}\}/u);
  assert.match(workflow, /persist-credentials: false/u);
  assert.match(workflow, /actions\/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1/u);
  assert.match(workflow, /actions\/setup-node@820762786026740c76f36085b0efc47a31fe5020/u);
  assert.doesNotMatch(workflow, /candidate/u);
  assert.doesNotMatch(workflow, /pull_request:/u);
  assert.match(runner, /createTrustedEvaluator/u);
  assert.match(runner, /collectGateInput/u);
  assert.doesNotMatch(runner, /checkout|execSync|child_process|candidate/u);
  assert.match(runner, /finalPullRequest/u);
  assert.match(runner, /renderDiagnosticSummary/u);
});

test("publishes the stable summary and result output", () => {
  assert.match(runner, /GITHUB_STEP_SUMMARY/u);
  assert.match(runner, /GITHUB_OUTPUT/u);
  assert.match(runner, /renderDiagnosticSummary/u);
  assert.match(runner, /GITHUB_TOKEN/u);
});

test("renders an obsolete result when the head advances before publication", async () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "agent-session-manager-ci-gate-workflow-"));
  const summaryPath = path.join(temporary, "summary.md");
  const outputPath = path.join(temporary, "output.txt");
  const headSha = "a".repeat(40);
  const nextHeadSha = "d".repeat(40);
  let pullRequestReads = 0;
  const fetchImplementation = async url => {
    const parsed = new URL(url);
    if (parsed.pathname.endsWith("/pulls/7")) {
      pullRequestReads += 1;
      return new Response(JSON.stringify({head: {sha: pullRequestReads === 5 ? nextHeadSha : headSha, repo: {full_name: "owner/repo"}}, base: {sha: "b".repeat(40)}, draft: false}));
    }
    if (parsed.pathname.endsWith("/files")) return new Response(JSON.stringify({files: [{filename: "README.md"}]}));
    if (parsed.pathname.endsWith("/check-runs")) return new Response(JSON.stringify({check_runs: []}));
    if (parsed.pathname.endsWith("/actions/variables/ENABLE_MACOSX_JOBS")) return new Response("", {status: 404});
    if (parsed.pathname.endsWith("/actions/runs")) return new Response(JSON.stringify({workflow_runs: []}));
    throw new Error(`unexpected endpoint ${parsed.pathname}`);
  };
  const result = await runGate({
    environment: {
      CI_GATE_POLICY_ROOT: repositoryRoot,
      CI_GATE_POLICY_SHA: "c".repeat(40),
      GITHUB_TOKEN: "test-token",
      GITHUB_REPOSITORY: "owner/repo",
      PR_EVENT: "opened",
      PR_NUMBER: "7",
      CI_GATE_TIMEOUT_MS: "0",
      GITHUB_STEP_SUMMARY: summaryPath,
      GITHUB_OUTPUT: outputPath,
    },
    fetchImplementation,
    sleep: async () => {},
  });
  assert.equal(result.decision, "failure");
  assert.match(result.policyErrors.join(" "), /during publication/u);
  assert.match(fs.readFileSync(summaryPath, "utf8"), /Evaluated head SHA/u);
  assert.equal(fs.readFileSync(outputPath, "utf8").trim().split("\n").at(-1), "decision=failure");
});
