#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const markdownExtensions = new Set([".md", ".markdown", ".mdx"]);
const maximumPrintedFindings = 100;
const blockHtmlTags = new Set([
  "address",
  "article",
  "aside",
  "base",
  "blockquote",
  "body",
  "caption",
  "center",
  "col",
  "colgroup",
  "dd",
  "details",
  "dialog",
  "dir",
  "div",
  "dl",
  "dt",
  "fieldset",
  "figcaption",
  "figure",
  "footer",
  "form",
  "h1",
  "h2",
  "h3",
  "h4",
  "h5",
  "h6",
  "head",
  "header",
  "hr",
  "html",
  "iframe",
  "legend",
  "li",
  "link",
  "main",
  "menu",
  "menuitem",
  "nav",
  "ol",
  "p",
  "pre",
  "script",
  "section",
  "style",
  "summary",
  "table",
  "tbody",
  "td",
  "tfoot",
  "th",
  "thead",
  "title",
  "tr",
  "track",
  "ul",
]);

const listPattern = /^\s{0,3}(?:[-+*]|\d+[.)])\s+/u;
const blockquotePattern = /^\s{0,3}>\s?(.*)$/u;
const headingPattern = /^\s{0,3}#{1,6}(?:\s|$)/u;
const thematicBreakPattern = /^\s{0,3}(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})$/u;

function normalizedPath(filePath) {
  return filePath.split(path.sep).join("/");
}

function isMarkdownPath(filePath) {
  return markdownExtensions.has(path.posix.extname(normalizedPath(filePath)).toLowerCase());
}

function nonWhitespaceColumn(line) {
  const index = line.search(/\S/u);
  return index < 0 ? 1 : index + 1;
}

function finding(sourceChannel, source, line, column, reason) {
  const normalizedSource = sourceChannel === "file" ? normalizedPath(source) : source;
  return {
    sourceChannel,
    source: normalizedSource,
    file: sourceChannel === "file" ? normalizedSource : null,
    line,
    column,
    reason,
  };
}

function isBlank(line) {
  return /^\s*$/u.test(line);
}

function fenceAt(line) {
  const match = line.match(/^\s{0,3}(`{3,}|~{3,})(.*)$/u);
  if (!match) return null;
  return { character: match[1][0], length: match[1].length, remainder: match[2] };
}

function isFenceClose(line, fence) {
  const current = fenceAt(line);
  return current !== null
    && current.character === fence.character
    && current.length >= fence.length
    && current.remainder.trim() === "";
}

function isIndentedCode(line) {
  return /^(?: {4}|\t)\S/u.test(line);
}

function isTableSeparator(line) {
  const cells = line.trim().replace(/^\|/u, "").replace(/\|$/u, "").split("|");
  return cells.length > 0 && cells.every((cell) => /^\s*:?-{3,}:?\s*$/u.test(cell));
}

function isTableRow(line) {
  return line.includes("|") && !isBlank(line);
}

function isTableHeader(lines, index) {
  return index + 1 < lines.length && isTableRow(lines[index]) && isTableSeparator(lines[index + 1]);
}

function htmlOpeningTag(line) {
  const match = line.match(/^\s{0,3}<([A-Za-z][A-Za-z0-9:-]*)(?:\s[^>]*)?>\s*$/u);
  if (!match || !blockHtmlTags.has(match[1].toLowerCase())) return null;
  return match[1].toLowerCase();
}

function htmlClosingTag(line, tag) {
  return new RegExp(`^\\s{0,3}</${tag}\\s*>\\s*$`, "u").test(line);
}

function lineKind(line) {
  if (isBlank(line)) return "blank";
  if (headingPattern.test(line) || thematicBreakPattern.test(line)) return "structural";

  const blockquote = line.match(blockquotePattern);
  if (blockquote) {
    if (isBlank(blockquote[1])) return "blank";
    if (listPattern.test(blockquote[1])) return "list";
    return "blockquote";
  }

  if (listPattern.test(line)) return "list";
  return "paragraph";
}

function scanMarkdown(text, source, sourceChannel) {
  const lines = text.replace(/\r\n?/gu, "\n").split("\n");
  const findings = [];
  let frontMatter = lines[0]?.trim() === "---";
  let fence = null;
  let htmlComment = false;
  let htmlTag = null;
  let table = false;
  let activeBlock = null;

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];

    if (frontMatter) {
      if (index > 0 && ["---", "..."].includes(line.trim())) frontMatter = false;
      activeBlock = null;
      continue;
    }

    if (fence !== null) {
      if (isFenceClose(line, fence)) fence = null;
      activeBlock = null;
      continue;
    }

    if (htmlComment) {
      if (line.includes("-->")) htmlComment = false;
      activeBlock = null;
      continue;
    }

    if (htmlTag !== null) {
      if (htmlClosingTag(line, htmlTag)) htmlTag = null;
      activeBlock = null;
      continue;
    }

    const fenceStart = fenceAt(line);
    if (fenceStart !== null) {
      fence = fenceStart;
      activeBlock = null;
      continue;
    }

    const trimmed = line.trimStart();
    if (trimmed.startsWith("<!--")) {
      htmlComment = !trimmed.includes("-->");
      activeBlock = null;
      continue;
    }

    const openingTag = htmlOpeningTag(line);
    if (openingTag !== null) {
      if (!line.includes(`</${openingTag}>`) && !line.endsWith("/>")) htmlTag = openingTag;
      activeBlock = null;
      continue;
    }

    if (/^\s{0,3}<\/[A-Za-z][A-Za-z0-9:-]*\s*>\s*$/u.test(line)) {
      activeBlock = null;
      continue;
    }

    if (table) {
      if (isTableRow(line)) {
        activeBlock = null;
        continue;
      }
      table = false;
    }

    if (isTableHeader(lines, index)) {
      table = true;
      activeBlock = null;
      continue;
    }

    if (isIndentedCode(line)) {
      activeBlock = null;
      continue;
    }

    const kind = lineKind(line);
    if (kind === "blank" || kind === "structural") {
      activeBlock = null;
      continue;
    }

    const continuesBlock = activeBlock !== null
      && ((activeBlock.kind === kind && kind !== "list") || (activeBlock.kind === "list" && kind === "paragraph"));
    if (continuesBlock) {
      findings.push(finding(
        sourceChannel,
        source,
        index + 1,
        nonWhitespaceColumn(line),
        "non-empty continuation line in logical prose block",
      ));
    }

    activeBlock = { kind };
  }

  return findings;
}

export function scanText(text, source, sourceChannel = "file") {
  if (sourceChannel === "commit-body") return [];
  if (sourceChannel === "file" && !isMarkdownPath(source)) return [];
  return scanMarkdown(text, source, sourceChannel);
}

export function scanPullRequestDescription(text) {
  return scanText(text, "pull-request-description", "pull-request-description");
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
    if (!isMarkdownPath(relativePath)) continue;
    const absolutePath = path.join(root, relativePath);
    if (!fs.lstatSync(absolutePath).isFile()) continue;
    const buffer = fs.readFileSync(absolutePath);
    if (isBinary(buffer)) continue;
    findings.push(...scanText(buffer.toString("utf8"), relativePath));
  }
  return findings;
}

function formatFinding(violation) {
  return `${violation.sourceChannel}:${violation.source}:${violation.line}:${violation.column}: ${violation.reason}`;
}

function argumentValue(name) {
  const index = process.argv.indexOf(name);
  return index < 0 ? null : process.argv[index + 1];
}

function printUsage() {
  console.error("Usage: fixed-width-prose.mjs [--root <repository>] [--pull-request-description-file <path>]");
}

function main() {
  const root = path.resolve(argumentValue("--root") ?? process.cwd());
  const bodyPath = argumentValue("--pull-request-description-file");

  let findings;
  try {
    findings = scanRepository(root);
    if (bodyPath) findings.push(...scanPullRequestDescription(fs.readFileSync(bodyPath, "utf8")));
  } catch (error) {
    console.error(`fixed-width-prose: ${error.message}`);
    printUsage();
    process.exitCode = 1;
    return;
  }

  for (const violation of findings.slice(0, maximumPrintedFindings)) console.error(formatFinding(violation));
  if (findings.length > maximumPrintedFindings) {
    console.error(`fixed-width-prose: showing first ${maximumPrintedFindings} of ${findings.length} findings`);
  }

  if (findings.length > 0) {
    console.error(`fixed-width-prose: ${findings.length} violation(s) found`);
    process.exitCode = 1;
    return;
  }

  console.log("fixed-width-prose: no violations found");
}

if (import.meta.url === `file://${process.argv[1]}`) main();
