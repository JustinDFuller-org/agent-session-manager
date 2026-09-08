import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const repositoryRoot = path.resolve(new URL("../..", import.meta.url).pathname);
const workflow = name => fs.readFileSync(path.join(repositoryRoot, ".github/workflows", name), "utf8");
const pullRequestTypes = "types: [opened, edited, synchronize, reopened, ready_for_review, converted_to_draft]";
const macOSPaths = ["Sources/**", "Tests/**", "UITests/**", "Package.swift", "Package.resolved", "project.yml", "Makefile", "scripts/**", ".swift-version", ".xcode-version", "*.xcconfig", "*.plist", "Sources/**/Resources/**", "Assets.xcassets/**", ".github/**", ".agents/**", "openspec/**"];
const pullRequestBlock = source => {
  const lines = source.split("\n");
  const start = lines.findIndex(line => line === "  pull_request:");
  if (start < 0) return [];
  const endOffset = lines.slice(start + 1).findIndex(line => /^  [a-zA-Z0-9_-]+:/u.test(line));
  return lines.slice(start, endOffset < 0 ? lines.length : start + 1 + endOffset);
};

test("all matrix workflows observe every gate event and cancel superseded revisions", () => {
  for (const name of ["pr-quality.yml", "openspec.yml", "openspec-guide.yml", "no-code-comments.yml", "no-fixed-width-prose.yml", "format.yml", "lint.yml", "docs.yml", "swift-build-check.yml", "unit-tests.yml", "ui-tests.yml", "dependency-toolchain-compatibility.yml"]) {
    const source = workflow(name);
    assert.match(source, new RegExp(pullRequestTypes.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "u"), name);
    assert.match(source, /concurrency:/u, name);
    assert.match(source, /cancel-in-progress: true/u, name);
    assert.doesNotMatch(pullRequestBlock(source).join("\n"), /branches:/u, `${name} restricts PR target branches`);
  }
});

test("macOS workflow filters cover the trusted application surface and exact false is the only PR opt-out", () => {
  for (const name of ["unit-tests.yml", "ui-tests.yml", "dependency-toolchain-compatibility.yml"]) {
    const source = workflow(name);
    for (const pattern of macOSPaths) assert.match(source, new RegExp(`- "${pattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}"`, "u"), `${name} missing ${pattern}`);
    assert.match(source, /github\.event_name != 'pull_request' \|\| vars\.ENABLE_MACOSX_JOBS != 'false'/u, name);
  }
});

test("privileged validators use immutable workflow source and pinned actions", () => {
  for (const name of ["ci-gate.yml", "openspec.yml", "no-code-comments.yml", "no-fixed-width-prose.yml"]) {
    const source = workflow(name);
    assert.match(source, /github\.event\.repository\.default_branch/u, name);
    for (const action of source.matchAll(/^\s+uses:\s+([^@]+)@([^\s]+)$/gmu)) assert.match(action[2], /^[0-9a-f]{40}$/u, `${name} has an unpinned action`);
    assert.match(source, /permissions: \{\}/u, name);
  }
  assert.match(workflow("ci-gate.yml"), /pull_request_target:/u);
  assert.doesNotMatch(workflow("ci-gate.yml"), /candidate|pull_request:/u);
  for (const name of ["openspec.yml", "no-code-comments.yml", "no-fixed-width-prose.yml"]) assert.match(workflow(name), /pull_request_target:/u, name);
});

test("all workflow action references are immutable commit pins", () => {
  const workflowsDirectory = path.join(repositoryRoot, ".github/workflows");
  for (const name of fs.readdirSync(workflowsDirectory).filter(name => name.endsWith(".yml"))) {
    const source = workflow(name);
    for (const action of source.matchAll(/^\s+uses:\s+([^@]+)@([^\s]+)$/gmu)) assert.match(action[2], /^[0-9a-f]{40}$/u, `${name} has an unpinned ${action[1]} reference`);
  }
});
