import assert from "node:assert/strict";
import test from "node:test";

import { scanText } from "./no-code-comments.mjs";

function locations(findings) {
  return findings.map(({ line, column, kind }) => ({ line, column, kind }));
}

test("reports C-style line and block comments with locations", () => {
  const source = ["let first = 1; // first", "/* second */ let third = 3;"].join("\n");
  const findings = scanText(source, "Example.swift");
  assert.deepEqual(locations(findings), [
    { line: 1, column: source.indexOf("//") + 1, kind: "line comment" },
    { line: 2, column: 1, kind: "block comment" },
  ]);
});

test("reports hash comments but ignores shebangs and heredoc data", () => {
  const source = [
    "#!/usr/bin/env bash",
    "value=1 # first",
    "cat <<EOF",
    "# heredoc data",
    "EOF",
    "# second",
  ].join("\n");
  const findings = scanText(source, "script.sh");
  assert.deepEqual(locations(findings), [
    { line: 2, column: 9, kind: "hash comment" },
    { line: 6, column: 1, kind: "hash comment" },
  ]);
});

test("reports XML comments", () => {
  const source = "<root><!-- explanation --><value /></root>";
  const findings = scanText(source, "Info.plist");
  assert.deepEqual(locations(findings), [
    { line: 1, column: 7, kind: "XML comment" },
  ]);
});

test("ignores comment-like text in strings, URLs, regular expressions, and colors", () => {
  const source = [
    'const url = "https://example.test/a//b";',
    'const line = "// not a comment";',
    'const block = "/* not a comment */";',
    "const pattern = /https?:\\/\\//;",
    'const color = "#fff";',
    "body { color: #fff; }",
  ].join("\n");
  assert.deepEqual(scanText(source, "Example.mjs"), []);
  assert.deepEqual(scanText("body { color: #fff; }", "style.scss"), []);
});

test("ignores Swift raw strings, multiline strings, and embedded scripts", () => {
  const source = [
    'let raw = #"// raw data"#',
    'let multiline = """',
    "// multiline data",
    '"""',
    'let hook = """',
    "#!/bin/bash",
    "# embedded data",
    '"""',
  ].join("\n");
  assert.deepEqual(scanText(source, "Example.swift"), []);
});

test("allows the SwiftPM tools-version directive", () => {
  const source = "// swift-tools-version: 6.1\nimport PackageDescription\n";
  assert.deepEqual(scanText(source, "Package.swift"), []);
});

test("does not allow the SwiftPM tools-version directive outside its first line", () => {
  const source = "import PackageDescription\n// swift-tools-version: 6.1\n";
  const findings = scanText(source, "Package.swift");
  assert.deepEqual(locations(findings), [
    { line: 2, column: 1, kind: "line comment" },
  ]);
});
