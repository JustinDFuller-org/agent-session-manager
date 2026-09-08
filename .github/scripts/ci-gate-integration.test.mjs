import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const repositoryRoot = path.resolve(new URL("../..", import.meta.url).pathname);
const workflow = name => fs.readFileSync(path.join(repositoryRoot, ".github/workflows", name), "utf8");
const pullRequestTypes = "types: [opened, edited, synchronize, reopened, ready_for_review, converted_to_draft]";
const macOSPaths = ["Sources/**", "Tests/**", "UITests/**", "Package.swift", "Package.resolved", "project.yml", "*.xcodeproj/**", "*.xcworkspace/**", "Makefile", "scripts/**", ".swift-version", ".xcode-version", "*.xcconfig", "*.plist", "Sources/**/Resources/**", "Assets.xcassets/**", ".github/**", ".agents/**", "openspec/**"];
const pullRequestBlock = source => {
  const lines = source.split("\n");
  const start = lines.findIndex(line => line === "  pull_request:" || line === "  pull_request_target:");
  if (start < 0) return [];
  const endOffset = lines.slice(start + 1).findIndex(line => /^  [a-zA-Z0-9_-]+:/u.test(line));
  return lines.slice(start, endOffset < 0 ? lines.length : start + 1 + endOffset);
};
const workflowJobBlocks = source => {
  const jobsStart = source.indexOf("\njobs:\n");
  if (jobsStart < 0) return [];
  return source.slice(jobsStart + 7).split(/\n(?=  [a-zA-Z0-9_-]+:\n)/u);
};
const checkoutSteps = source => source.split(/\n(?=      - )/u).filter(step => /uses: actions\/checkout@[0-9a-f]{40}/u.test(step));

test("all matrix workflows observe every gate event and cancel superseded revisions", () => {
  for (const name of ["pr-quality.yml", "openspec.yml", "openspec-guide.yml", "no-code-comments.yml", "no-fixed-width-prose.yml", "format.yml", "lint.yml", "docs.yml", "swift-build-check.yml", "unit-tests.yml", "ui-tests.yml", "dependency-toolchain-compatibility.yml"]) {
    const source = workflow(name);
    assert.match(pullRequestBlock(source).join("\n"), new RegExp(pullRequestTypes.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "u"), name);
    assert.match(source, /concurrency:/u, name);
    assert.match(source, /cancel-in-progress: true/u, name);
    assert.doesNotMatch(pullRequestBlock(source).join("\n"), /branches:/u, `${name} restricts PR target branches`);
  }
});

test("macOS workflow filters cover the trusted application surface and exact false is the only PR opt-out", () => {
  for (const name of ["unit-tests.yml", "ui-tests.yml", "dependency-toolchain-compatibility.yml"]) {
    const source = workflow(name);
    const pullRequest = pullRequestBlock(source).join("\n");
    for (const pattern of macOSPaths) assert.match(pullRequest, new RegExp(`- "${pattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}"`, "u"), `${name} missing ${pattern}`);
    assert.match(source, /macos-policy:\n[\s\S]*?if \[\[ "\$GITHUB_EVENT_NAME" != "pull_request" \|\| "\$ENABLE_MACOSX_JOBS" != "false" \]\]/u, name);
    assert.match(source, /if: needs\.macos-policy\.outputs\.enabled == 'true'/u, name);
  }
});

test("privileged validators use immutable workflow source and pinned actions", () => {
  for (const name of ["ci-gate.yml", "openspec.yml", "no-code-comments.yml", "no-fixed-width-prose.yml", "openspec-guide.yml"]) {
    const source = workflow(name);
    for (const action of source.matchAll(/^\s+uses:\s+([^@]+)@([^\s]+)$/gmu)) assert.match(action[2], /^[0-9a-f]{40}$/u, `${name} has an unpinned action`);
    assert.match(source, /permissions: \{\}/u, name);
    const sourceCheckout = checkoutSteps(source)[0];
    assert.ok(sourceCheckout, `${name} has no checkout step`);
    if (name === "openspec-guide.yml") {
      assert.match(sourceCheckout, /ref: \$\{\{ github\.event\.pull_request\.head\.sha \}\}/u, name);
    } else {
      assert.match(sourceCheckout, /ref: \$\{\{ github\.event\.repository\.default_branch \}\}/u, name);
    }
  }
  assert.match(workflow("ci-gate.yml"), /pull_request_target:/u);
  assert.doesNotMatch(workflow("ci-gate.yml"), /candidate|pull_request:/u);
  for (const name of ["openspec.yml", "openspec-guide.yml", "no-code-comments.yml", "no-fixed-width-prose.yml"]) assert.match(workflow(name), /pull_request_target:/u, name);
  assert.match(workflow("openspec-guide.yml"), /ref: \$\{\{ github\.event\.pull_request\.head\.sha \}\}/u);
});

test("all workflow action references are immutable commit pins", () => {
  const workflowsDirectory = path.join(repositoryRoot, ".github/workflows");
  for (const name of fs.readdirSync(workflowsDirectory).filter(name => name.endsWith(".yml"))) {
    const source = workflow(name);
    for (const action of source.matchAll(/^\s+uses:\s+([^@]+)@([^\s]+)$/gmu)) assert.match(action[2], /^[0-9a-f]{40}$/u, `${name} has an unpinned ${action[1]} reference`);
  }
});

test("candidate workflows have explicit permission floors and no checkout credentials", () => {
  for (const name of ["ci-gate.yml", "pr-quality.yml", "openspec.yml", "openspec-guide.yml", "no-code-comments.yml", "no-fixed-width-prose.yml", "format.yml", "lint.yml", "docs.yml", "swift-build-check.yml", "unit-tests.yml", "ui-tests.yml", "dependency-toolchain-compatibility.yml"]) {
    const source = workflow(name);
    assert.match(source, /^permissions: \{\}$/mu, name);
    for (const permissionBlock of source.matchAll(/^    permissions:\n((?:      [a-z-]+: [^\n]+\n)+)/gmu)) {
      for (const entry of permissionBlock[1].matchAll(/^      ([a-z-]+): ([a-z]+)$/gmu)) {
        assert.match(entry[1], /^(?:actions|checks|contents|pull-requests)$/u, `${name} has an unexpected permission`);
        const permittedPullRequestWrite = ["openspec.yml", "openspec-guide.yml"].includes(name) && entry[1] === "pull-requests" && entry[2] === "write";
        assert.ok(entry[2] === "read" || permittedPullRequestWrite, `${name} grants an unexpected writable permission`);
      }
    }
    const checkoutCount = checkoutSteps(source).length;
    if (checkoutCount > 0) {
      const jobBlocks = workflowJobBlocks(source);
      const checkoutJobBlocks = jobBlocks.filter(block => /uses: actions\/checkout@[0-9a-f]{40}/u.test(block));
      const parsedCheckoutSteps = checkoutJobBlocks.flatMap(jobBlock => jobBlock.split(/\n(?=      - )/u).filter(step => /uses: actions\/checkout@[0-9a-f]{40}/u.test(step)));
      assert.equal(parsedCheckoutSteps.length, checkoutCount, `${name} has a checkout outside a parsed job block`);
      for (const jobBlock of checkoutJobBlocks) {
        assert.match(jobBlock, /^    permissions:\n(?:      [a-z-]+: [^\n]+\n)*      contents: read(?:\n|$)/mu, `${name} checkout job lacks contents read`);
        const checkoutSteps = jobBlock.split(/\n(?=      - )/u).filter(step => /uses: actions\/checkout@[0-9a-f]{40}/u.test(step));
        for (const checkoutStep of checkoutSteps) assert.match(checkoutStep, /\n        with:\n(?:          (?!persist-credentials: false)[^\n]*\n)*          persist-credentials: false(?:\n|$)/u, `${name} checkout step persists credentials`);
      }
    }
  }
});
