import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  scanPullRequestDescription,
  scanRepository,
  scanText,
} from "./fixed-width-prose.mjs";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const validatorPath = path.join(repositoryRoot, ".github/scripts/fixed-width-prose.mjs");

function locations(findings) {
  return findings.map(({ sourceChannel, source, line, reason }) => ({ sourceChannel, source, line, reason }));
}

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "fixed-width-prose-"));
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

test("reports a wrapped paragraph with channel, source, line, and reason", () => {
  const source = "A paragraph that should stay together.\nThis continuation is a violation.\n";
  assert.deepEqual(locations(scanText(source, "README.md")), [{
    sourceChannel: "file",
    source: "README.md",
    line: 2,
    reason: "non-empty continuation line in logical prose block",
  }]);
});

test("accepts one-line paragraphs and blank-separated paragraphs", () => {
  const source = "First paragraph.\n\nSecond paragraph.\n";
  assert.deepEqual(scanText(source, "README.md"), []);
});

test("reports wrapped list items and blockquotes", () => {
  const source = [
    "- First list item.",
    "  continuation of the list item.",
    "",
    "> First blockquote line.",
    "> continuation of the blockquote.",
  ].join("\n");
  assert.deepEqual(locations(scanText(source, "README.md")), [
    {
      sourceChannel: "file",
      source: "README.md",
      line: 2,
      reason: "non-empty continuation line in logical prose block",
    },
    {
      sourceChannel: "file",
      source: "README.md",
      line: 5,
      reason: "non-empty continuation line in logical prose block",
    },
  ]);
});

test("accepts separate one-line list items", () => {
  const source = "- First item.\n- Second item.\n1. Third item.\n";
  assert.deepEqual(scanText(source, "README.md"), []);
});

test("accepts fenced and indented code, tables, front matter, headings, thematic breaks, and raw HTML", () => {
  const source = [
    "---",
    "title: Example",
    "description: Multiple front matter lines are structural.",
    "---",
    "# Heading",
    "---",
    "```swift",
    "let first = 1",
    "let second = 2",
    "```",
    "    indented code line one",
    "    indented code line two",
    "| Name | Value |",
    "| --- | --- |",
    "| first | one |",
    "| second | two |",
    "<div>",
    "HTML content line one.",
    "HTML content line two.",
    "</div>",
  ].join("\n");
  assert.deepEqual(scanText(source, "README.md"), []);
});

test("does not use a width threshold for continuations", () => {
  const source = "Short.\nAlso short.\n";
  assert.equal(scanText(source, "README.md").length, 1);
});

test("scans pull-request descriptions with the same rule", () => {
  const findings = scanPullRequestDescription("Pull-request paragraph.\nWrapped continuation.\n");
  assert.deepEqual(locations(findings), [{
    sourceChannel: "pull-request-description",
    source: "pull-request-description",
    line: 2,
    reason: "non-empty continuation line in logical prose block",
  }]);
});

test("commit bodies are guidance-only and do not create blocking findings", () => {
  assert.deepEqual(scanText("Commit paragraph.\nWrapped commit body.\n", "commit-message", "commit-body"), []);
});

test("scans every tracked Markdown-family file in a repository", () => {
  const root = fixture();
  write(root, "README.md", "Clean paragraph.\n");
  write(root, "documentation/guide.markdown", "Wrapped paragraph.\nContinuation.\n");
  write(root, "skill.mdx", "Another clean paragraph.\n");
  write(root, "ignored.txt", "Wrapped text.\nContinuation.\n");
  track(root);

  assert.deepEqual(locations(scanRepository(root)), [{
    sourceChannel: "file",
    source: "documentation/guide.markdown",
    line: 2,
    reason: "non-empty continuation line in logical prose block",
  }]);
});

test("clean repository exits successfully", () => {
  const root = fixture();
  write(root, "README.md", "Clean paragraph.\n");
  track(root);

  const result = spawnSync(process.execPath, [validatorPath, "--root", root], { encoding: "utf8" });
  assert.equal(result.status, 0);
  assert.match(result.stdout, /no violations found/);
});

test("violating repository exits with an actionable diagnostic", () => {
  const root = fixture();
  write(root, "README.md", "Wrapped paragraph.\nContinuation.\n");
  track(root);

  const result = spawnSync(process.execPath, [validatorPath, "--root", root], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /file:README\.md:2:1: non-empty continuation line/);
});

test("CLI reports pull-request description source findings", () => {
  const root = fixture();
  write(root, "README.md", "Clean paragraph.\n");
  track(root);
  const bodyPath = path.join(root, "pull-request-body.txt");
  fs.writeFileSync(bodyPath, "PR paragraph.\nWrapped PR paragraph.\n");

  const result = spawnSync(process.execPath, [
    validatorPath,
    "--root",
    root,
    "--pull-request-description-file",
    bodyPath,
  ], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /pull-request-description:pull-request-description:2:1: non-empty continuation line/);
});

test("CLI bounds diagnostic output while reporting the total", () => {
  const root = fixture();
  const paragraphs = Array.from({ length: 101 }, (_, index) => `Paragraph ${index}.\nContinuation ${index}.`);
  write(root, "README.md", `${paragraphs.join("\n\n")}\n`);
  track(root);

  const result = spawnSync(process.execPath, [validatorPath, "--root", root], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.equal((result.stderr.match(/non-empty continuation line/g) ?? []).length, 100);
  assert.match(result.stderr, /showing first 100 of 101 findings/);
});

test("the Makefile exposes the repository-local validator command", () => {
  const makefile = fs.readFileSync(path.join(repositoryRoot, "Makefile"), "utf8");
  assert.match(makefile, /no-fixed-width-prose:\n\tnode \.github\/scripts\/fixed-width-prose\.mjs --root "\$\(CURDIR\)"/u);
});
