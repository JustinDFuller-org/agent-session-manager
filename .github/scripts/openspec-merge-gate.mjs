#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const OPEN_SPEC_PACKAGE = "@fission-ai/openspec@1.10.0";

function directoryEntries(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(directory, entry.name));
}

function markdownFiles(directory) {
  if (!fs.existsSync(directory)) return [];
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...markdownFiles(entryPath));
    else if (entry.isFile() && entry.name.endsWith(".md")) files.push(entryPath);
  }
  return files;
}

function readFileIfPresent(filePath) {
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

function hasSkipSpecs(metadata) {
  return /^\s*skip_specs\s*:\s*true\s*$/m.test(metadata);
}

function taskCounts(tasksPath) {
  const content = readFileIfPresent(tasksPath);
  if (content === null) return null;
  const tasks = [...content.matchAll(/^\s*- \[([ xX])\]/gm)];
  return {
    total: tasks.length,
    completed: tasks.filter((match) => match[1].toLowerCase() === "x").length,
  };
}

export function resolveCandidateTarget(event) {
  if (event.name === "pull_request_target") {
    const repository = event.pullRequest?.head?.repository;
    const sha = event.pullRequest?.head?.sha;
    if (!repository?.fullName || !sha) {
      throw new Error("Pull request head repository and immutable SHA are required");
    }
    return { repository: repository.fullName, ref: sha };
  }

  if (!event.repository || !event.sha) {
    throw new Error("Repository and immutable SHA are required");
  }
  return { repository: event.repository, ref: event.sha };
}

export function stackContext(environment = process.env) {
  const stackBase = environment.STACK_BASE_REF?.trim() || "";
  const directBase = environment.PR_BASE_REF?.trim() || "";
  const positionText = environment.STACK_POSITION?.trim() || "";
  const position = positionText === "" ? null : Number(positionText);
  const validPosition = Number.isInteger(position) && position > 0;

  if (!stackBase && !positionText) {
    return { kind: "ordinary", strict: true, directBase };
  }

  if (!stackBase || !validPosition || !directBase) {
    return { kind: "unknown", strict: true, directBase, stackBase, position };
  }

  if (stackBase === directBase) {
    return { kind: "base", strict: true, directBase, stackBase, position };
  }

  return { kind: "higher", strict: true, directBase, stackBase, position };
}

export function archiveGuidance(environment = process.env) {
  const stack = stackContext(environment);
  if (stack.kind === "higher") {
    return `This is higher implementation layer ${stack.position} of a stack targeting '${stack.stackBase}'. Do not archive the OpenSpec change in this PR. Complete the implementation here, then complete tasks and archive the change in the base PR targeting '${stack.directBase}', cascade-rebase this stack, and rerun the check.`;
  }

  if (stack.kind === "base") {
    return `This is the base PR for a stack targeting '${stack.stackBase}'. Complete all tasks and archive the OpenSpec change in this PR, then cascade-rebase higher implementation PRs before merging the stack.`;
  }

  return "Complete all tasks and archive the OpenSpec change in this PR before merging.";
}

export function inspectCandidate(candidateDirectory, environment = process.env) {
  const openSpecDirectory = path.join(candidateDirectory, "openspec");
  const changesDirectory = path.join(openSpecDirectory, "changes");
  const archiveDirectory = path.join(changesDirectory, "archive");
  const activeChanges = directoryEntries(changesDirectory)
    .filter((directory) => path.basename(directory) !== "archive");
  const archivedChanges = directoryEntries(archiveDirectory);
  const findings = [];
  const guidance = archiveGuidance(environment);

  if (activeChanges.length === 0 && archivedChanges.length === 0) {
    findings.push("No OpenSpec change was found in the candidate checkout. Add the required spec-driven change before merging.");
  }

  if (activeChanges.length > 0) {
    const names = activeChanges.map((directory) => path.basename(directory)).join(", ");
    findings.push(`Active OpenSpec change(s) remain: ${names}. ${guidance}`);
  }

  if (archivedChanges.length === 0) {
    findings.push(`No archived OpenSpec change was found. ${guidance}`);
  }

  const allChanges = [...activeChanges, ...archivedChanges];
  for (const changeDirectory of allChanges) {
    const metadataPath = path.join(changeDirectory, ".openspec.yaml");
    const metadata = readFileIfPresent(metadataPath);
    if (metadata === null) {
      findings.push(`OpenSpec change '${path.basename(changeDirectory)}' is missing .openspec.yaml.`);
    } else if (hasSkipSpecs(metadata)) {
      findings.push(`OpenSpec change '${path.basename(changeDirectory)}' uses skip_specs: true, which is not permitted.`);
    }

    const counts = taskCounts(path.join(changeDirectory, "tasks.md"));
    if (counts === null) {
      findings.push(`OpenSpec change '${path.basename(changeDirectory)}' is missing tasks.md.`);
    } else if (counts.completed < counts.total) {
      findings.push(`OpenSpec checklist incomplete for '${path.basename(changeDirectory)}': ${counts.completed}/${counts.total} tasks complete. ${guidance}`);
    }

    const requiredFiles = ["proposal.md", "design.md", "tasks.md"];
    for (const requiredFile of requiredFiles) {
      if (!fs.existsSync(path.join(changeDirectory, requiredFile))) {
        findings.push(`OpenSpec change '${path.basename(changeDirectory)}' is missing ${requiredFile}.`);
      }
    }

    const deltaSpecs = markdownFiles(path.join(changeDirectory, "specs"));
    if (deltaSpecs.length === 0) {
      findings.push(`OpenSpec change '${path.basename(changeDirectory)}' is missing a delta specification.`);
    } else if (archivedChanges.includes(changeDirectory)) {
      for (const deltaSpec of deltaSpecs) {
        const relativeSpec = path.relative(path.join(changeDirectory, "specs"), deltaSpec);
        const mainSpec = path.join(openSpecDirectory, "specs", relativeSpec);
        if (!fs.existsSync(mainSpec)) {
          findings.push(`Archived OpenSpec change '${path.basename(changeDirectory)}' is missing corresponding main specification openspec/specs/${relativeSpec}.`);
        }
      }
    }
  }

  if (archivedChanges.length > 0 && markdownFiles(path.join(openSpecDirectory, "specs")).length === 0) {
    findings.push("The archived OpenSpec change has no corresponding main specification under openspec/specs/.");
  }

  return { findings, activeChanges, archivedChanges, stack: stackContext(environment) };
}

function runOpenSpecCommand(candidateDirectory, args) {
  const result = spawnSync("npx", ["--yes", OPEN_SPEC_PACKAGE, ...args], {
    cwd: candidateDirectory,
    encoding: "utf8",
    maxBuffer: 1024 * 1024,
  });
  if (result.error) {
    return { status: 1, output: result.error.message };
  }
  return {
    status: result.status ?? 1,
    output: `${result.stdout ?? ""}${result.stderr ?? ""}`.trim(),
  };
}

export function validateCandidate(candidateDirectory, environment = process.env, options = {}) {
  const inspected = inspectCandidate(candidateDirectory, environment);
  const findings = [...inspected.findings];

  if (options.runCli !== false) {
    for (const args of [
      ["validate", "--archived", "--no-interactive"],
      ["validate", "--all", "--strict", "--no-interactive"],
    ]) {
      const result = runOpenSpecCommand(candidateDirectory, args);
      if (result.status !== 0) {
        findings.push(`OpenSpec command '${args.join(" ")}' failed:\n${result.output || "No diagnostic output was returned."}`);
      }
    }
  }

  return { ...inspected, findings };
}

function printFindings(findings) {
  for (const finding of findings) {
    for (const line of finding.split("\n")) console.log(`::error::${line}`);
  }
}

function main() {
  const candidateIndex = process.argv.indexOf("--candidate");
  const candidateDirectory = candidateIndex >= 0 ? process.argv[candidateIndex + 1] : null;
  if (!candidateDirectory) {
    console.error("Usage: openspec-merge-gate.mjs --candidate <directory>");
    process.exit(2);
  }

  const result = validateCandidate(candidateDirectory);
  if (result.findings.length > 0) {
    printFindings(result.findings);
    process.exit(1);
  }
  console.log("OpenSpec presence, artifact completeness, and strict validation passed.");
}

if (import.meta.url === `file://${process.argv[1]}`) main();
