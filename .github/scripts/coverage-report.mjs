import fs from "node:fs";
import path from "node:path";

export const sourceRoots = ["Sources/AgentSessionManager", "Sources/AgentSessionManagerMCPBridgeCore"];

function repositoryPath(file, root) {
  const absoluteRoot = path.resolve(root);
  const absoluteFile = path.resolve(root, file);
  const relativeFile = path.relative(absoluteRoot, absoluteFile);
  if (relativeFile.startsWith("..") || path.isAbsolute(relativeFile)) {
    return null;
  }
  const normalized = relativeFile.split(path.sep).join("/");
  return sourceRoots.some((sourceRoot) => normalized === sourceRoot || normalized.startsWith(`${sourceRoot}/`))
    ? normalized
    : null;
}

function records(report) {
  const lines = report.split(/\r?\n/);
  const result = [];
  let record = [];
  for (const line of lines) {
    if (line === "end_of_record") {
      if (record.length === 0 || !record.some((entry) => entry.startsWith("SF:"))) {
        throw new Error("malformed LCOV record");
      }
      result.push(record.concat(line));
      record = [];
    } else if (line.length > 0) {
      record.push(line);
    }
  }
  if (record.length > 0 || result.length === 0) {
    throw new Error("malformed or empty LCOV report");
  }
  return result;
}

function recordPath(record) {
  const sourceLine = record.find((line) => line.startsWith("SF:"));
  if (!sourceLine || sourceLine === "SF:") {
    throw new Error("malformed LCOV record");
  }
  return sourceLine.slice(3);
}

export function filterReport(report, root = process.cwd()) {
  const filtered = records(report).filter((record) => repositoryPath(recordPath(record), root));
  if (filtered.length === 0) {
    throw new Error("LCOV report contains no repository source files");
  }
  return `${filtered.map((record) => record.join("\n")).join("\n")}\n`;
}

export function validateReport(report, root = process.cwd()) {
  const parsed = records(report);
  for (const record of parsed) {
    if (!repositoryPath(recordPath(record), root)) {
      throw new Error(`LCOV source path is outside repository sources: ${recordPath(record)}`);
    }
    if (!record.some((line) => /^DA:.+,\d+$/.test(line))) {
      throw new Error("malformed LCOV record");
    }
  }
  return parsed.length;
}

function option(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? null : process.argv[index + 1];
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try {
    const input = option("--input");
    const output = option("--output");
    const root = option("--root") ?? process.cwd();
    if (!input || !output) {
      throw new Error("usage: coverage-report.mjs --input FILE --output FILE [--root DIRECTORY]");
    }
    const report = filterReport(fs.readFileSync(input, "utf8"), root);
    validateReport(report, root);
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.writeFileSync(output, report);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
