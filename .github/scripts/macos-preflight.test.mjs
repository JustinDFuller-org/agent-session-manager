import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  classifyChangedPaths,
  parseMacOSMode,
  readChangedPaths,
  resolveComparisonBase,
  runPreflight,
} from "./macos-preflight.mjs";

test("documentation-only changes are not applicable", () => {
  const result = parseMacOSMode({paths: ["documentation/how-to/build.md", "README.md"], variable: "true"});
  assert.equal(result.mode, "not-applicable");
});

test("source, build, and enforcement changes require macOS validation", () => {
  const result = parseMacOSMode({paths: ["Sources/App.swift", "Makefile", ".github/workflows/ci-gate.yml"], variable: "true"});
  assert.equal(result.mode, "required");
  assert.deepEqual(result.classification.categories, ["build", "enforcement", "source"]);
});

test("unknown paths require macOS validation", () => {
  const result = parseMacOSMode({paths: ["new-file.bin"], variable: "true"});
  assert.equal(result.mode, "required");
  assert.deepEqual(result.classification.unknownPaths, ["new-file.bin"]);
});

test("exact false disables relevant macOS validation", () => {
  assert.equal(parseMacOSMode({paths: ["Sources/App.swift"], variable: "false"}).mode, "disabled-policy");
});

test("true enables relevant macOS validation", () => {
  assert.equal(parseMacOSMode({paths: ["Sources/App.swift"], variable: "true"}).mode, "required");
});

test("missing and malformed variables fail closed", () => {
  assert.equal(parseMacOSMode({paths: ["Sources/App.swift"], variable: undefined}).mode, "required");
  assert.equal(parseMacOSMode({paths: ["Sources/App.swift"], variable: "TRUE"}).mode, "required");
});

test("stack base takes precedence over immediate pull-request base", () => {
  assert.equal(resolveComparisonBase({stackBase: "stack", pullRequestBase: "immediate"}), "stack");
  assert.equal(resolveComparisonBase({stackBase: "", pullRequestBase: "immediate"}), "immediate");
});

test("missing revisions fail closed", () => {
  assert.throws(() => resolveComparisonBase({stackBase: "", pullRequestBase: ""}), /missing stack-base/);
});

test("Git preflight reads the stack-base-to-head diff", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "agent-session-manager-macos-preflight-"));
  execFileSync("git", ["init", "-q", "-b", "main"], {cwd: root});
  execFileSync("git", ["config", "user.email", "test@example.com"], {cwd: root});
  execFileSync("git", ["config", "user.name", "Test"], {cwd: root});
  fs.mkdirSync(path.join(root, "Sources"));
  fs.writeFileSync(path.join(root, "Sources", "App.swift"), "one");
  execFileSync("git", ["add", "."], {cwd: root});
  execFileSync("git", ["commit", "-qm", "base"], {cwd: root});
  const base = execFileSync("git", ["rev-parse", "HEAD"], {cwd: root, encoding: "utf8"}).trim();
  fs.writeFileSync(path.join(root, "Sources", "App.swift"), "two");
  execFileSync("git", ["commit", "-qam", "head"], {cwd: root});
  const head = execFileSync("git", ["rev-parse", "HEAD"], {cwd: root, encoding: "utf8"}).trim();
  assert.deepEqual(readChangedPaths({root, base, head}), ["Sources/App.swift"]);
  assert.equal(runPreflight({root, stackBase: base, pullRequestBase: "wrong", head, variable: "true"}).mode, "required");
});

test("invalid Git revisions fail closed", () => {
  assert.throws(() => readChangedPaths({root: process.cwd(), base: "not-a-revision", head: "HEAD"}));
});

test("classification records all matching relevant categories", () => {
  const result = classifyChangedPaths(["Tests/AppTests.swift", "Package.swift", "project.yml", "App.xcodeproj/project.pbxproj", "Sources/App/Resources/Info.plist"]);
  assert.deepEqual(result.categories, ["package", "project", "resources", "source", "tests"]);
  assert.equal(result.unknownPaths.length, 0);
});
