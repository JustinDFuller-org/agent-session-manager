#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const OPEN_SPEC_PACKAGE = "@fission-ai/openspec@1.10.0";

function readFileIfPresent(filePath) {
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

function directoryNames(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function markdownFiles(directory) {
  if (!fs.existsSync(directory)) return [];
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...markdownFiles(entryPath));
    else if (entry.isFile() && entry.name.endsWith(".md")) files.push(entryPath);
  }
  return files.sort();
}

function hasSkipSpecs(metadata) {
  return /^\s*skip_specs\s*:\s*true\s*$/m.test(metadata);
}

function hasSpecDrivenSchema(metadata) {
  return /^\s*schema\s*:\s*spec-driven\s*$/m.test(metadata);
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

function setsEqual(left, right) {
  return left.size === right.size && [...left].every((value) => right.has(value));
}

function difference(left, right) {
  return new Set([...left].filter((value) => !right.has(value)));
}

function intersection(left, right) {
  return new Set([...left].filter((value) => right.has(value)));
}

function namesText(names) {
  return [...names].sort().join(", ");
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
  const eventName = environment.EVENT_NAME || "pull_request_target";
  if (eventName === "push") {
    return { kind: "push", phase: "post-merge", strict: true, isTop: false };
  }

  const directBase = environment.PR_BASE_REF?.trim() || "";
  const stackBase = environment.STACK_BASE_REF?.trim() || "";
  const stackBaseSha = environment.STACK_BASE_SHA?.trim() || "";
  const positionText = environment.STACK_POSITION?.trim() || "";
  const sizeText = environment.STACK_SIZE?.trim() || "";
  const stackPresence = environment.STACK_PRESENT?.trim() || "";
  const hasStackMetadata = [stackBase, stackBaseSha, positionText, sizeText].some(Boolean);
  if ((stackPresence && !["true", "false"].includes(stackPresence))
    || (stackPresence === "false" && hasStackMetadata)) {
    return { kind: "unknown", phase: "unknown", strict: true, isTop: false, directBase };
  }
  const stackPresent = stackPresence === "true" || hasStackMetadata;

  if (!stackPresent) {
    if (!directBase) {
      return { kind: "unknown", phase: "unknown", strict: true, isTop: false, directBase };
    }
    return { kind: "standalone", phase: "finalization", strict: true, isTop: true, directBase };
  }

  const position = positionText === "" ? null : Number(positionText);
  const size = sizeText === "" ? null : Number(sizeText);
  const defaultBranch = environment.DEFAULT_BRANCH?.trim() || "main";
  const validNumbers = Number.isInteger(position) && position > 0
    && Number.isInteger(size) && size > 0 && position <= size;
  if (!stackBase || !stackBaseSha || !directBase || !validNumbers || stackBase !== defaultBranch) {
    return {
      kind: "unknown",
      phase: "unknown",
      strict: true,
      isTop: false,
      directBase,
      stackBase,
      stackBaseSha,
      position,
      size,
    };
  }

  const isTop = position === size;
  return {
    kind: isTop ? "top" : "non-top",
    phase: isTop ? "finalization" : "continuation",
    strict: true,
    isTop,
    directBase,
    stackBase,
    stackBaseSha,
    position,
    size,
  };
}

export function archiveGuidance(environment = process.env) {
  const stack = stackContext(environment);
  if (stack.kind === "non-top") {
    return `This is non-top stack layer ${stack.position} of ${stack.size}. Continue implementation or QA here; leave the shared OpenSpec change active. Only the current top layer archives it.`;
  }
  if (stack.kind === "top" || stack.kind === "standalone") {
    return "This is the finalization layer. Complete every task and submit an archive-only pull request for the shared change.";
  }
  if (stack.kind === "unknown") {
    return "Stack metadata is malformed or unsupported; the check fails closed until the pull request has valid main-rooted stack context.";
  }
  return "The push validation checks the committed OpenSpec artifacts on the default branch.";
}

function inspectTree(root) {
  const openSpecDirectory = path.join(root, "openspec");
  const changesDirectory = path.join(openSpecDirectory, "changes");
  const archiveDirectory = path.join(changesDirectory, "archive");
  const activeChanges = new Set(directoryNames(changesDirectory).filter((name) => name !== "archive"));
  const archivedChanges = new Set(directoryNames(archiveDirectory));
  const findings = [];

  if (activeChanges.size === 0 && archivedChanges.size === 0) {
    findings.push("No OpenSpec change was found in the candidate checkout. Add the required spec-driven change before merging.");
  }

  for (const [name, directory] of [
    ...[...activeChanges].map((name) => [name, path.join(changesDirectory, name)]),
    ...[...archivedChanges].map((name) => [name, path.join(archiveDirectory, name)]),
  ]) {
    const metadataPath = path.join(directory, ".openspec.yaml");
    const metadata = readFileIfPresent(metadataPath);
    if (metadata === null) {
      findings.push(`OpenSpec change '${name}' is missing .openspec.yaml.`);
    } else {
      if (!hasSpecDrivenSchema(metadata)) findings.push(`OpenSpec change '${name}' must use schema: spec-driven.`);
      if (hasSkipSpecs(metadata)) findings.push(`OpenSpec change '${name}' uses skip_specs: true, which is not permitted.`);
    }

    for (const requiredFile of ["proposal.md", "design.md", "tasks.md"]) {
      if (!fs.existsSync(path.join(directory, requiredFile))) {
        findings.push(`OpenSpec change '${name}' is missing ${requiredFile}.`);
      }
    }

    const deltaSpecs = markdownFiles(path.join(directory, "specs"));
    if (deltaSpecs.length === 0) {
      findings.push(`OpenSpec change '${name}' is missing a delta specification.`);
    } else if (archivedChanges.has(name)) {
      for (const deltaSpec of deltaSpecs) {
        const relativeSpec = path.relative(path.join(directory, "specs"), deltaSpec);
        const mainSpec = path.join(openSpecDirectory, "specs", relativeSpec);
        if (!fs.existsSync(mainSpec)) {
          findings.push(`Archived OpenSpec change '${name}' is missing corresponding main specification openspec/specs/${relativeSpec}.`);
        }
      }
    }

    const counts = taskCounts(path.join(directory, "tasks.md"));
    if (counts === null) continue;
    if (counts.total === 0) findings.push(`OpenSpec change '${name}' has no task checklist items.`);
  }

  if (archivedChanges.size > 0 && markdownFiles(path.join(openSpecDirectory, "specs")).length === 0) {
    findings.push("Archived OpenSpec changes require corresponding main specifications under openspec/specs/.");
  }

  return { findings, activeChanges, archivedChanges };
}

function treeFiles(root) {
  const files = new Map();
  if (!root || !fs.existsSync(root)) return files;

  function visit(directory, relativeDirectory = "") {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (entry.name === ".git") continue;
      const relativePath = path.posix.join(relativeDirectory, entry.name);
      const entryPath = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(entryPath, relativePath);
      else if (entry.isFile()) {
        const digest = crypto.createHash("sha256").update(fs.readFileSync(entryPath)).digest("hex");
        files.set(relativePath, digest);
      }
    }
  }

  visit(root);
  return files;
}

export function changedPaths(baseDirectory, candidateDirectory) {
  const baseFiles = treeFiles(baseDirectory);
  const candidateFiles = treeFiles(candidateDirectory);
  const paths = new Set([...baseFiles.keys(), ...candidateFiles.keys()]);
  return [...paths].filter((filePath) => baseFiles.get(filePath) !== candidateFiles.get(filePath)).sort();
}

function pathsUnder(root, prefix) {
  const files = treeFiles(root);
  return new Set([...files.keys()].filter((filePath) => filePath === prefix || filePath.startsWith(`${prefix}/`)));
}

function relativePathsUnder(root, prefix) {
  return new Set([...pathsUnder(root, prefix)].map((filePath) => filePath.slice(prefix.length + 1)));
}

function archiveDirectoryName(root, name) {
  const archiveDirectory = path.join(root, "openspec", "changes", "archive");
  const names = directoryNames(archiveDirectory);
  if (names.includes(name)) return name;
  const datedNames = names.filter((candidate) => candidate.replace(/^\d{4}-\d{2}-\d{2}-/, "") === name
    && /^\d{4}-\d{2}-\d{2}-.+/.test(candidate));
  return datedNames.length === 1 ? datedNames[0] : null;
}

function archivePrefix(root, name) {
  return `openspec/changes/archive/${archiveDirectoryName(root, name) || name}`;
}

function archiveTransitionFindings(immediateBase, candidate, expectedNames) {
  const findings = [];
  const changed = new Set(changedPaths(immediateBase, candidate));
  const allowed = new Set();
  const required = new Set();
  const candidateMainSpecs = new Set();

  for (const name of expectedNames) {
    const activePrefix = `openspec/changes/${name}`;
    const candidateArchivePrefix = archivePrefix(candidate, name);
    const activeRelative = relativePathsUnder(immediateBase, activePrefix);
    const archiveRelative = relativePathsUnder(candidate, candidateArchivePrefix);
    const immediateHasActive = activeRelative.size > 0;

    if (immediateHasActive) {
      const expectedRelative = [...activeRelative].sort();
      const actualRelative = [...archiveRelative].sort();
      if (expectedRelative.length !== actualRelative.length || expectedRelative.some((value, index) => value !== actualRelative[index])) {
        findings.push(`Archive transition for '${name}' must move the exact active change contents without adding or removing files.`);
      }
      for (const relativePath of activeRelative) {
        const activePath = `${activePrefix}/${relativePath}`;
        const archivePath = `${candidateArchivePrefix}/${relativePath}`;
        allowed.add(activePath);
        allowed.add(archivePath);
        required.add(activePath);
        required.add(archivePath);
        if (!changed.has(activePath) || !changed.has(archivePath)) {
          findings.push(`Archive transition for '${name}' is incomplete: expected ${activePath} -> ${archivePath}.`);
        }
        const activeDigest = treeFiles(immediateBase).get(activePath);
        const archiveDigest = treeFiles(candidate).get(archivePath);
        if (activeDigest !== archiveDigest) {
          findings.push(`Archive transition for '${name}' changed file contents at '${relativePath}'; archival must preserve the reviewed change.`);
        }
      }
    } else {
      for (const relativePath of archiveRelative) {
        const archivePath = `${candidateArchivePrefix}/${relativePath}`;
        allowed.add(archivePath);
        required.add(archivePath);
        if (!changed.has(archivePath)) findings.push(`New archived change '${name}' has an unchanged archive file where a new file was expected.`);
      }
      if (archiveRelative.size === 0) findings.push(`New archived change '${name}' has no archive files.`);
    }

    for (const relativePath of relativePathsUnder(candidate, `${candidateArchivePrefix}/specs`)) {
      const mainSpec = `openspec/specs/${relativePath}`;
      candidateMainSpecs.add(mainSpec);
      allowed.add(mainSpec);
    }
  }

  for (const filePath of changed) {
    if (!allowed.has(filePath)) {
      findings.push(`Final archive pull request is not archive-only: unexpected changed path '${filePath}'. ${archiveGuidance({ ...process.env, EVENT_NAME: "pull_request_target" })}`);
    }
  }

  for (const requiredPath of required) {
    if (!changed.has(requiredPath)) findings.push(`Final archive pull request is missing required changed path '${requiredPath}'.`);
  }

  for (const mainSpec of candidateMainSpecs) {
    if (!fs.existsSync(path.join(candidate, mainSpec))) {
      findings.push(`Archived change is missing corresponding main specification '${mainSpec}'.`);
    }
  }

  return findings;
}

function archiveOnlyFindings(immediateBase, candidate, expectedNames) {
  const findings = archiveTransitionFindings(immediateBase, candidate, expectedNames);
  const changed = changedPaths(immediateBase, candidate);
  const expectedMainSpecs = new Set();
  for (const name of expectedNames) {
    for (const relativePath of relativePathsUnder(candidate, `${archivePrefix(candidate, name)}/specs`)) {
      expectedMainSpecs.add(`openspec/specs/${relativePath}`);
    }
  }
  for (const filePath of changed.filter((filePath) => filePath.startsWith("openspec/specs/"))) {
    if (!expectedMainSpecs.has(filePath)) {
      findings.push(`Final archive pull request changes unrelated main specification '${filePath}'.`);
    }
  }
  return findings;
}

function phaseFindings(candidate, immediateBase, trunk, stack, environment) {
  const findings = [];
  const candidateState = inspectTree(candidate);
  const immediateState = inspectTree(immediateBase);
  const trunkState = inspectTree(trunk);
  const guidance = archiveGuidance(environment);

  if (stack.kind === "unknown") {
    findings.push("OpenSpec stack context is missing, malformed, or not rooted at the default branch.");
    return findings;
  }

  if (stack.kind === "push") return findings;

  const expectedFromBase = immediateState.activeChanges;
  if (expectedFromBase.size > 0) {
    const inheritedHistorical = intersection(expectedFromBase, trunkState.archivedChanges);
    if (inheritedHistorical.size > 0) {
      findings.push(`The stack reuses archived OpenSpec change name(s) already on the trunk: ${namesText(inheritedHistorical)}.`);
    }

    if (!stack.isTop) {
      if (!setsEqual(candidateState.activeChanges, expectedFromBase)) {
        findings.push(`OpenSpec change-set mismatch: this layer must carry exactly the active names from its immediate base (${namesText(expectedFromBase)}), but it has active names (${namesText(candidateState.activeChanges)}).`);
      }
      if (!setsEqual(candidateState.archivedChanges, immediateState.archivedChanges)) {
        findings.push(`Non-top layer archived change-set mismatch: do not add or remove archived changes before finalization.`);
      }
      if (changedPaths(immediateBase, candidate).some((filePath) => filePath.startsWith("openspec/changes/archive/"))) {
        findings.push(`Non-top layer changed an archived OpenSpec path. Continue implementation or QA and leave archival to the current top layer. ${guidance}`);
      }
      return findings;
    }

    if (candidateState.activeChanges.size > 0) {
      findings.push(`Top finalization layer still has active OpenSpec change(s): ${namesText(candidateState.activeChanges)}. ${guidance}`);
    }
    const expectedArchivedDirectories = new Set([...expectedFromBase]
      .map((name) => archiveDirectoryName(candidate, name))
      .filter(Boolean));
    const newArchives = difference(candidateState.archivedChanges, immediateState.archivedChanges);
    if (!setsEqual(newArchives, expectedArchivedDirectories)) {
      findings.push(`OpenSpec archive-set mismatch: the top layer must archive exactly (${namesText(expectedFromBase)}), but the new archived names are (${namesText(newArchives)}).`);
    }
    findings.push(...archiveOnlyFindings(immediateBase, candidate, expectedFromBase));
    return findings;
  }

  if (!stack.isTop) {
    const newActive = difference(candidateState.activeChanges, trunkState.activeChanges);
    const inheritedActive = intersection(candidateState.activeChanges, trunkState.activeChanges);
    const archivedConflict = intersection(newActive, trunkState.archivedChanges);
    if (newActive.size === 0) {
      findings.push(`Bottom stack layer must introduce at least one new active OpenSpec change absent from the trunk. ${guidance}`);
    }
    if (inheritedActive.size > 0) {
      findings.push(`Bottom stack layer carries active change name(s) already present on the trunk: ${namesText(inheritedActive)}.`);
    }
    if (archivedConflict.size > 0) {
      findings.push(`Bottom stack layer reuses archived change name(s) already on the trunk: ${namesText(archivedConflict)}.`);
    }
    if (!setsEqual(candidateState.archivedChanges, immediateState.archivedChanges)) {
      findings.push("Bottom stack layer changed the archived change-set before finalization.");
    }
    return findings;
  }

  if (candidateState.activeChanges.size > 0) {
    findings.push(`Finalization layer must not retain active OpenSpec change(s): ${namesText(candidateState.activeChanges)}. ${guidance}`);
  }
  const newArchives = difference(candidateState.archivedChanges, trunkState.archivedChanges);
  if (newArchives.size === 0) {
    findings.push(`Finalization layer must introduce a new archived OpenSpec change absent from the trunk. ${guidance}`);
  }
  const archivedConflict = intersection(newArchives, trunkState.archivedChanges);
  if (archivedConflict.size > 0) {
    findings.push(`Finalization layer relies on archived change(s) already present on the trunk: ${namesText(archivedConflict)}.`);
  }
  const activeConflict = intersection(newArchives, trunkState.activeChanges);
  if (activeConflict.size > 0) {
    findings.push(`Finalization layer archives active change(s) already present on the trunk: ${namesText(activeConflict)}.`);
  }
  findings.push(...archiveOnlyFindings(immediateBase, candidate, newArchives));
  return findings;
}

function finalizationFindings(candidate, stack) {
  if (!stack.isTop) return [];
  const state = inspectTree(candidate);
  const findings = [];
  for (const name of [...state.activeChanges, ...state.archivedChanges]) {
    const counts = taskCounts(path.join(candidate, "openspec", "changes", state.archivedChanges.has(name) ? "archive" : "", name, "tasks.md"));
    if (counts && counts.completed !== counts.total) {
      findings.push(`OpenSpec checklist incomplete for '${name}': ${counts.completed}/${counts.total} tasks complete. Complete every task before finalization.`);
    }
  }
  return findings;
}

function runOpenSpecCommand(candidateDirectory, args) {
  const safeDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "agent-session-manager-openspec-cli-"));
  try {
    fs.symlinkSync(path.join(candidateDirectory, "openspec"), path.join(safeDirectory, "openspec"), "dir");
    const result = spawnSync("npx", ["--yes", OPEN_SPEC_PACKAGE, ...args], {
      cwd: safeDirectory,
      env: {
        ...Object.fromEntries(Object.entries(process.env).filter(([name]) => !/(credential|password|private|secret|token)/iu.test(name))),
        NPM_CONFIG_IGNORE_SCRIPTS: "true",
        NPM_CONFIG_USERCONFIG: path.join(safeDirectory, "npmrc"),
      },
      encoding: "utf8",
      maxBuffer: 1024 * 1024,
    });
    if (result.error) return {status: 1, output: result.error.message};
    return {status: result.status ?? 1, output: `${result.stdout ?? ""}${result.stderr ?? ""}`.trim()};
  } finally {
    fs.rmSync(safeDirectory, {force: true, recursive: true});
  }
}

export function validateCandidate(candidateDirectory, environment = process.env, options = {}) {
  const inspected = inspectTree(candidateDirectory);
  const findings = [...inspected.findings];
  const stack = stackContext(environment);
  const eventName = environment.EVENT_NAME || "pull_request_target";

  if (eventName !== "push") {
    const trunk = options.trunkDirectory || environment.TRUNK_DIRECTORY;
    const immediateBase = options.immediateBaseDirectory || environment.IMMEDIATE_BASE_DIRECTORY;
    if (!trunk || !immediateBase) {
      findings.push("Immutable stack-trunk and immediate-base snapshots are required for pull-request validation.");
    } else {
      findings.push(...phaseFindings(candidateDirectory, immediateBase, trunk, stack, environment));
      if (stack.isTop) findings.push(...finalizationFindings(candidateDirectory, stack));
    }
  }

  if (options.runCli !== false) {
    for (const args of [["validate", "--archived", "--no-interactive"], ["validate", "--all", "--strict", "--no-interactive"]]) {
      const result = runOpenSpecCommand(candidateDirectory, args);
      if (result.status !== 0) {
        findings.push(`OpenSpec command '${args.join(" ")}' failed:\n${result.output || "No diagnostic output was returned."}`);
      }
    }
  }

  return { ...inspected, stack, findings };
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
  console.log(`OpenSpec ${result.stack.phase} validation passed.`);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
