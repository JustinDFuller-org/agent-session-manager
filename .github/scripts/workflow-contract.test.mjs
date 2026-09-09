import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const workflowRoot = path.join(repositoryRoot, ".github/workflows");
const caller = fs.readFileSync(path.join(workflowRoot, "ci-gate.yml"), "utf8");
const reusableWorkflows = [
  "pr-quality.yml",
  "openspec.yml",
  "no-code-comments.yml",
  "no-fixed-width-prose.yml",
  "format.yml",
  "lint.yml",
  "docs.yml",
  "swift-build-check.yml",
  "unit-tests.yml",
  "ui-tests.yml",
  "dependency-toolchain-compatibility.yml",
];

function workflow(name) {
  return fs.readFileSync(path.join(workflowRoot, name), "utf8");
}

test("all required validations expose workflow_call and the caller invokes each", () => {
  for (const name of reusableWorkflows) {
    assert.match(workflow(name), /workflow_call:/u, name);
    assert.match(caller, new RegExp(`\\.github/workflows/${name.replaceAll(".", "\\.")}`, "u"), name);
  }
});

test("caller is unfiltered for required workflow files and runs on the stack trunk", () => {
  assert.match(caller, /pull_request:\n    branches: \[main\]/u);
  assert.match(caller, /types: \[opened, edited, synchronize, reopened, ready_for_review, converted_to_draft\]/u);
  assert.doesNotMatch(caller, /paths:/u);
  assert.doesNotMatch(caller, /pull_request_target:/u);
});

test("macOS callers wait for preflight and every lightweight validation", () => {
  const required = ["macos_preflight", "pr_quality", "openspec", "no_code_comments", "no_fixed_width_prose", "swift_format", "swiftlint", "docs", "resolve"];
  for (const job of ["unit_tests", "ui_tests", "compatibility"]) {
    const start = caller.indexOf(`  ${job}:`);
    const section = caller.slice(start).split(/\n  [a-z][a-z_]*:/u)[0];
    for (const prerequisite of required) assert.match(section, new RegExp(`\\b${prerequisite}\\b`, "u"), `${job} missing ${prerequisite}`);
    assert.match(section, /macos_preflight\.outputs\.macos_mode == 'required'/u);
    assert.match(section, /always\(\)/u);
  }
});

test("final gate uses always and explicitly handles intentional macOS skips", () => {
  const section = caller.slice(caller.indexOf("  ci_gate:"));
  for (const job of ["macos_preflight", "pr_quality", "openspec", "no_code_comments", "no_fixed_width_prose", "swift_format", "swiftlint", "docs", "resolve", "unit_tests", "ui_tests", "compatibility"]) {
    assert.match(section, new RegExp(`\\b${job}\\b`, "u"), `gate missing ${job}`);
  }
  assert.match(section, /if: \$\{\{ always\(\) \}\}/u);
  assert.match(section, /disabled-policy/u);
  assert.match(section, /not-applicable/u);
  assert.match(section, /expected skipped/u);
});

test("workflow permissions are empty by default and third-party actions are SHA pinned", () => {
  for (const name of fs.readdirSync(workflowRoot).filter(name => name.endsWith(".yml"))) {
    const source = workflow(name);
    assert.match(source, /permissions: \{\}/u, name);
    for (const match of source.matchAll(/uses: ([^\s]+)@([^\s]+)/gu)) {
      if (match[1].startsWith("./")) continue;
      assert.match(match[2], /^[0-9a-f]{40}$/u, `${name} uses unpinned ${match[1]}`);
    }
  }
  assert.doesNotMatch(caller, /wip\/action/u);
});

test("guide comments and labels remain separate best-effort automation", () => {
  const guide = workflow("openspec-guide.yml");
  assert.match(guide, /pull_request_target:/u);
  assert.match(guide, /openspec-label:/u);
  assert.match(guide, /issues\.addLabels/u);
  assert.doesNotMatch(caller, /openspec-guide|openspec-label/u);
  assert.doesNotMatch(workflow("openspec.yml"), /openspec-label:/u);
});

test("legacy policy and API polling are absent", () => {
  assert.equal(fs.existsSync(path.join(repositoryRoot, ".github/ci-gate-policy.json")), false);
  for (const name of ["ci-gate-api.mjs", "ci-gate-evaluator.mjs", "ci-gate-workflow.mjs"]) {
    assert.equal(fs.existsSync(path.join(repositoryRoot, ".github/scripts", name)), false, name);
  }
  assert.doesNotMatch(caller, /poll|check-runs|GITHUB_TOKEN/u);
});
