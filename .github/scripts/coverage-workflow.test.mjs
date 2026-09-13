import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const workflow = fs.readFileSync(new URL("../workflows/unit-tests.yml", import.meta.url), "utf8");

test("coverage workflow has the required triggers and read-only policy", () => {
  assert.match(workflow, /push:\n    branches: \[main\]/);
  assert.match(workflow, /pull_request:\n    branches: \[main\]/);
  assert.match(workflow, /workflow_dispatch:/);
  assert.match(workflow, /permissions:\n  contents: read/);
  assert.match(workflow, /if: \$\{\{ vars\.ENABLE_MACOSX_JOBS == 'true' \}\}/);
});

test("coverage workflow checks out the reviewed pull-request commit", () => {
  assert.match(workflow, /ref: \$\{\{ github\.event\.pull_request\.head\.sha \|\| github\.sha \}\}/);
});

test("coverage workflow exports, validates, summarizes, and uploads ordinary LCOV", () => {
  assert.match(workflow, /swift test .*--enable-code-coverage/);
  assert.match(workflow, /find .*\.xctest\/Contents\/MacOS/);
  assert.match(workflow, /find \.build .*\.profdata/);
  assert.match(workflow, /xcrun llvm-cov export --format=lcov/);
  assert.match(workflow, /coverage-report\.mjs/);
  assert.match(workflow, /xcrun llvm-cov report/);
  assert.match(workflow, /actions\/upload-artifact@v7/);
  assert.match(workflow, /name: unit-test-coverage/);
  assert.doesNotMatch(workflow, /code-quality|codecov|coveralls/i);
  assert.doesNotMatch(workflow, /write/);
});
