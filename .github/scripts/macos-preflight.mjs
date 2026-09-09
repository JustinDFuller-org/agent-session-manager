import {execFileSync} from "node:child_process";
import fs from "node:fs";

const maxChangedFiles = 3000;

const documentationOnlyPatterns = [
  "documentation/**",
  "README.md",
  "USER_FACING_DOCS.md",
  "AGENTS.md",
  "CLAUDE.md",
  "AGENTIC_CONTROL.md",
  "OPENCODE_SUPPORT.md",
  "PROGRESS.md",
];

const relevantPatterns = {
  resources: ["Sources/**/Resources/**", "Assets.xcassets/**"],
  source: ["Sources/**"],
  tests: ["Tests/**", "UITests/**"],
  package: ["Package.swift", "Package.resolved"],
  project: ["project.yml", "*.xcodeproj/**", "*.xcworkspace/**"],
  build: ["Makefile", "scripts/**", "*.xcconfig", "*.plist"],
  toolchain: [".swift-version", ".xcode-version"],
  enforcement: [".github/**", ".agents/**", "openspec/**"],
};

function matchesPattern(filePath, pattern) {
  let expression = "^";
  for (let index = 0; index < pattern.length;) {
    if (pattern.startsWith("**", index)) {
      expression += ".*";
      index += 2;
    } else if (pattern[index] === "*") {
      expression += "[^/]*";
      index += 1;
    } else {
      expression += pattern[index].replace(/[.+?^${}()|[\]\\]/g, "\\$&");
      index += 1;
    }
  }
  return new RegExp(`${expression}$`, "u").test(filePath);
}

export function isDocumentationOnlyPath(filePath) {
  return documentationOnlyPatterns.some(pattern => matchesPattern(filePath, pattern));
}

export function classifyChangedPaths(paths) {
  const categories = new Set();
  const unknownPaths = [];
  for (const filePath of paths) {
    let classified = false;
    for (const [category, patterns] of Object.entries(relevantPatterns)) {
      if (patterns.some(pattern => matchesPattern(filePath, pattern))) {
        categories.add(category);
        classified = true;
      }
    }
    if (!classified && !isDocumentationOnlyPath(filePath)) unknownPaths.push(filePath);
  }
  const documentationOnly = paths.length > 0 && paths.every(isDocumentationOnlyPath);
  return {categories: [...categories].sort(), documentationOnly, unknownPaths};
}

export function parseMacOSMode({paths, variable}) {
  const classification = classifyChangedPaths(paths);
  if (classification.documentationOnly) {
    return {mode: "not-applicable", reason: "all changed paths are documentation-only", classification};
  }
  if (variable === "false") {
    return {mode: "disabled-policy", reason: "ENABLE_MACOSX_JOBS is exactly false", classification};
  }
  const reason = classification.unknownPaths.length > 0
    ? `unknown changed paths require macOS validation: ${classification.unknownPaths.join(", ")}`
    : variable === "true"
      ? "ENABLE_MACOSX_JOBS is exactly true"
      : variable == null || variable === ""
        ? "ENABLE_MACOSX_JOBS is missing; macOS validation is required"
        : "ENABLE_MACOSX_JOBS is malformed; macOS validation is required";
  return {mode: "required", reason, classification};
}

export function resolveComparisonBase({stackBase, pullRequestBase}) {
  const selected = stackBase?.trim() || pullRequestBase?.trim() || "";
  if (!selected) throw new Error("missing stack-base and pull-request base revisions");
  return selected;
}

export function readChangedPaths({root, base, head, maxFiles = maxChangedFiles}) {
  const output = execFileSync("git", ["diff", "--name-only", "--no-renames", "-z", base, head, "--"], {
    cwd: root,
    encoding: "buffer",
    stdio: ["ignore", "pipe", "pipe"],
  });
  const paths = output.toString("utf8").split("\0").filter(Boolean);
  if (paths.length > maxFiles) throw new Error(`changed-file manifest exceeds ${maxFiles} paths`);
  return paths;
}

export function writeOutput(result, outputPath) {
  const output = [
    `macos_mode=${result.mode}`,
    `macos_reason=${result.reason}`,
    `macos_categories=${result.classification.categories.join(",")}`,
  ].join("\n") + "\n";
  fs.appendFileSync(outputPath, output);
}

function argumentsFrom(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 1) {
    if (!argv[index].startsWith("--")) throw new Error(`unexpected argument '${argv[index]}'`);
    const key = argv[index].slice(2);
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`missing value for --${key}`);
    values[key] = value;
    index += 1;
  }
  return values;
}

export function runPreflight({root, stackBase, pullRequestBase, head, variable, outputPath}) {
  const base = resolveComparisonBase({stackBase, pullRequestBase});
  const paths = readChangedPaths({root, base, head});
  const result = parseMacOSMode({paths, variable});
  if (outputPath) writeOutput(result, outputPath);
  return {...result, base, head, paths};
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try {
    const values = argumentsFrom(process.argv.slice(2));
    const result = runPreflight({
      root: values.root || process.cwd(),
      stackBase: values["stack-base"],
      pullRequestBase: values["pull-request-base"],
      head: values.head,
      variable: process.env.ENABLE_MACOSX_JOBS,
      outputPath: values.output || process.env.GITHUB_OUTPUT,
    });
    console.log(`macos_mode=${result.mode}`);
    console.log(`macos_reason=${result.reason}`);
    console.log(`changed_paths=${result.paths.length}`);
  } catch (error) {
    console.error(`macOS preflight failed: ${error.message}`);
    process.exitCode = 1;
  }
}
