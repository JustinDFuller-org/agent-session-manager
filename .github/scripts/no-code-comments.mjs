#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const cStyleExtensions = new Set([
  ".c",
  ".cc",
  ".cpp",
  ".css",
  ".h",
  ".hpp",
  ".js",
  ".jsx",
  ".jsonc",
  ".kt",
  ".kts",
  ".m",
  ".mjs",
  ".mm",
  ".rs",
  ".scss",
  ".swift",
  ".ts",
  ".tsx",
  ".java",
  ".go",
]);

const hashExtensions = new Set([
  ".bash",
  ".cfg",
  ".conf",
  ".env",
  ".fish",
  ".ini",
  ".pl",
  ".pm",
  ".py",
  ".rb",
  ".r",
  ".sh",
  ".toml",
  ".yml",
  ".yaml",
  ".zsh",
]);

const xmlExtensions = new Set([
  ".entitlements",
  ".plist",
  ".svg",
  ".xml",
]);

const markdownExtensions = new Set([".md", ".markdown", ".mdx"]);

function normalizedPath(filePath) {
  return filePath.split(path.sep).join("/");
}

function syntaxFor(filePath, content) {
  const relativePath = normalizedPath(filePath);
  const baseName = path.posix.basename(relativePath);
  const extension = path.posix.extname(baseName).toLowerCase();

  if (markdownExtensions.has(extension)) return null;
  if (baseName === "Makefile" || baseName === "CODEOWNERS" || baseName === ".gitignore" || baseName === ".gitattributes") return "hash";
  if (relativePath.startsWith(".githooks/")) return "hash";
  if (cStyleExtensions.has(extension) || baseName === "Package.swift") return "c-style";
  if (hashExtensions.has(extension)) return "hash";
  if (xmlExtensions.has(extension)) return "xml";
  if (content.startsWith("#!")) return "hash";
  return null;
}

function positionAt(text, index) {
  let line = 1;
  let column = 1;
  for (let cursor = 0; cursor < index; cursor += 1) {
    if (text[cursor] === "\n") {
      line += 1;
      column = 1;
    } else {
      column += 1;
    }
  }
  return { line, column };
}

function finding(filePath, text, index, kind) {
  const position = positionAt(text, index);
  return {
    file: normalizedPath(filePath),
    line: position.line,
    column: position.column,
    kind,
  };
}

function isEscaped(text, index) {
  let slashCount = 0;
  for (let cursor = index - 1; cursor >= 0 && text[cursor] === "\\"; cursor -= 1) slashCount += 1;
  return slashCount % 2 === 1;
}

function stringDelimiterAt(text, index) {
  if (text.startsWith("\"\"\"", index) || text.startsWith("'''", index)) {
    return { openLength: 3, close: text.slice(index, index + 3) };
  }

  if (text[index] === "#" && text[index + 1] === "\"") {
    let hashCount = 0;
    while (text[index + hashCount] === "#") hashCount += 1;
    return { openLength: hashCount + 1, close: `\"${"#".repeat(hashCount)}` };
  }

  if (text[index] === "\"" || text[index] === "'" || text[index] === "`") {
    return { openLength: 1, close: text[index] };
  }

  return null;
}

function previousSignificantCharacter(text, index) {
  for (let cursor = index - 1; cursor >= 0; cursor -= 1) {
    if (!/\s/u.test(text[cursor])) return text[cursor];
  }
  return "";
}

function mayStartRegularExpression(text, index) {
  const previous = previousSignificantCharacter(text, index);
  return previous === "" || "([{:;,=!&|?+*%^~<>".includes(previous);
}

function skipRegularExpression(text, index) {
  let inCharacterClass = false;
  for (let cursor = index + 1; cursor < text.length; cursor += 1) {
    const character = text[cursor];
    if (character === "\n" || character === "\r") return index;
    if (character === "[" && !isEscaped(text, cursor)) inCharacterClass = true;
    if (character === "]" && !isEscaped(text, cursor)) inCharacterClass = false;
    if (character === "/" && !inCharacterClass && !isEscaped(text, cursor)) return cursor;
  }
  return index;
}

function scanCStyle(text, filePath) {
  const findings = [];
  let index = 0;
  let lineComment = false;
  let blockComment = false;
  let stringClose = null;

  while (index < text.length) {
    const character = text[index];

    if (lineComment) {
      if (character === "\n") lineComment = false;
      index += 1;
      continue;
    }

    if (blockComment) {
      if (text.startsWith("*/", index)) {
        blockComment = false;
        index += 2;
      } else {
        index += 1;
      }
      continue;
    }

    if (stringClose !== null) {
      if (text.startsWith(stringClose, index) && !isEscaped(text, index)) {
        index += stringClose.length;
        stringClose = null;
      } else {
        index += 1;
      }
      continue;
    }

    const delimiter = stringDelimiterAt(text, index);
    if (delimiter !== null) {
      stringClose = delimiter.close;
      index += delimiter.openLength;
      continue;
    }

    if (text.startsWith("//", index)) {
      const position = finding(filePath, text, index, "line comment");
      const firstLine = text.split("\n", 1)[0].trimEnd();
      const packageDirective = filePath === "Package.swift" && position.line === 1 && /^\/\/ swift-tools-version:\s*\S+\r?$/u.test(firstLine);
      if (!packageDirective) findings.push(position);
      lineComment = true;
      index += 2;
      continue;
    }

    if (text.startsWith("/*", index)) {
      findings.push(finding(filePath, text, index, "block comment"));
      blockComment = true;
      index += 2;
      continue;
    }

    if (character === "/" && (filePath.endsWith(".js") || filePath.endsWith(".mjs")) && mayStartRegularExpression(text, index)) {
      const end = skipRegularExpression(text, index);
      if (end !== index) {
        index = end + 1;
        continue;
      }
    }

    index += 1;
  }

  return findings;
}

function hashStartsComment(text, index) {
  if (index === 0 || text[index - 1] === "\n" || /\s/u.test(text[index - 1])) return true;
  return false;
}

function scanHash(text, filePath) {
  const findings = [];
  let index = 0;
  let stringClose = null;
  let heredocDelimiter = null;

  while (index < text.length) {
    const character = text[index];

    if (heredocDelimiter !== null && (index === 0 || text[index - 1] === "\n")) {
      const lineEnd = text.indexOf("\n", index) === -1 ? text.length : text.indexOf("\n", index);
      const line = text.slice(index, lineEnd).replace(/\r$/u, "");
      if (line === heredocDelimiter || line.replace(/^\t+/u, "") === heredocDelimiter) heredocDelimiter = null;
      index = lineEnd + 1;
      continue;
    }

    if (stringClose !== null) {
      if (character === stringClose && !isEscaped(text, index)) stringClose = null;
      index += 1;
      continue;
    }

    const delimiter = stringDelimiterAt(text, index);
    if (delimiter !== null && delimiter.openLength === 1) {
      stringClose = delimiter.close;
      index += delimiter.openLength;
      continue;
    }

    if (character === "#" && text[index + 1] !== "!" && hashStartsComment(text, index)) {
      const position = finding(filePath, text, index, "hash comment");
      if (position.line !== 1 || index !== 0) findings.push(position);
      while (index < text.length && text[index] !== "\n") index += 1;
      continue;
    }

    if (text.startsWith("<<", index)) {
      const lineEnd = text.indexOf("\n", index) === -1 ? text.length : text.indexOf("\n", index);
      const remainder = text.slice(index + 2, lineEnd).replace(/^[-~]/u, "").trim();
      const delimiterMatch = remainder.match(/^(?:'([^']+)'|"([^"]+)"|([A-Za-z_][A-Za-z0-9_]*))/u);
      if (delimiterMatch) heredocDelimiter = delimiterMatch[1] ?? delimiterMatch[2] ?? delimiterMatch[3];
      index = lineEnd + 1;
      continue;
    }

    if (character === "#" && text[index + 1] === "!" && index !== 0) {
      findings.push(finding(filePath, text, index, "hash comment"));
      while (index < text.length && text[index] !== "\n") index += 1;
      continue;
    }

    index += 1;
  }

  return findings;
}

function scanXml(text, filePath) {
  const findings = [];
  let index = 0;
  let stringClose = null;

  while (index < text.length) {
    const character = text[index];

    if (stringClose !== null) {
      if (character === stringClose && !isEscaped(text, index)) stringClose = null;
      index += 1;
      continue;
    }

    if (character === "\"" || character === "'") {
      stringClose = character;
      index += 1;
      continue;
    }

    if (text.startsWith("<!--", index)) {
      findings.push(finding(filePath, text, index, "XML comment"));
      index += 4;
      continue;
    }

    index += 1;
  }

  return findings;
}

export function scanText(text, filePath) {
  const syntax = syntaxFor(filePath, text);
  if (syntax === null) return [];
  if (syntax === "c-style") return scanCStyle(text, filePath);
  if (syntax === "hash") return scanHash(text, filePath);
  return scanXml(text, filePath);
}

function isBinary(buffer) {
  return buffer.includes(0);
}

function trackedFiles(root) {
  const result = spawnSync("git", ["ls-files", "-z"], {
    cwd: root,
    encoding: "buffer",
    maxBuffer: 32 * 1024 * 1024,
  });

  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error((result.stderr ?? Buffer.alloc(0)).toString("utf8").trim() || "git ls-files failed");
  return result.stdout.toString("utf8").split("\0").filter(Boolean);
}

export function scanRepository(root) {
  const findings = [];
  for (const relativePath of trackedFiles(root)) {
    const absolutePath = path.join(root, relativePath);
    if (!fs.lstatSync(absolutePath).isFile()) continue;
    const buffer = fs.readFileSync(absolutePath);
    if (isBinary(buffer)) continue;
    const text = buffer.toString("utf8");
    findings.push(...scanText(text, relativePath));
  }
  return findings;
}

function printUsage() {
  console.error("Usage: no-code-comments.mjs --root <repository>");
}

function main() {
  const rootIndex = process.argv.indexOf("--root");
  const root = rootIndex >= 0 ? process.argv[rootIndex + 1] : null;
  if (!root) {
    printUsage();
    process.exitCode = 2;
    return;
  }

  let findings;
  try {
    findings = scanRepository(path.resolve(root));
  } catch (error) {
    console.error(`no-code-comments: ${error.message}`);
    process.exitCode = 1;
    return;
  }

  for (const violation of findings) {
    console.error(`${violation.file}:${violation.line}:${violation.column}: ${violation.kind}`);
  }

  if (findings.length > 0) {
    console.error(`no-code-comments: ${findings.length} violation(s) found`);
    process.exitCode = 1;
    return;
  }

  console.log("no-code-comments: no violations found");
}

if (import.meta.url === `file://${process.argv[1]}`) main();
