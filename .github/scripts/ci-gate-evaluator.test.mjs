import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  assembleChangedFileManifest,
  classifyChangedFiles,
  createTrustedEvaluator,
  evaluateGate,
  expectedValidations,
  loadPolicy,
  parseMacOSPolicy,
  terminalStates,
  validatePolicy,
} from "./ci-gate-evaluator.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname, "..");
const policy = loadPolicy(root);
const repository = "JustinDFuller/agent-session-manager";
const headSha = "a".repeat(40);
const baseSha = "b".repeat(40);

const contextFor = (files = ["Sources/AgentSessionManager/App.swift"], variable = "true", headRepositoryFullName = repository) => ({
  repositoryFullName: repository,
  headRepositoryFullName,
  baseSha,
  pullRequestNumber: 353,
  headSha,
  draft: true,
  event: "edited",
  macOSVariable: variable,
  changedFiles: classifyChangedFiles(policy, files),
});

const completedEvidence = (context, overrides = {}) => {
  const checkRuns = [];
  const workflowRuns = [];
  const jobs = [];
  const runIDs = new Map();
  let nextRunID = 100;
  for (const validation of expectedValidations(policy, context)) {
    if (validation.state !== "waiting") continue;
    const workflowKey = `${validation.workflowName}:${validation.event}`;
    const runId = runIDs.get(workflowKey) ?? nextRunID++;
    runIDs.set(workflowKey, runId);
    if (!workflowRuns.some(run => run.id === runId)) {
      workflowRuns.push({id: runId, name: validation.workflowName, path: validation.workflowFile, head_sha: headSha, event: validation.event, pull_request_number: context.pullRequestNumber, status: "completed", conclusion: "success"});
      jobs.push({run_id: runId, name: validation.jobName, head_sha: headSha, status: "completed", conclusion: "success"});
    } else {
      jobs.push({run_id: runId, name: validation.jobName, head_sha: headSha, status: "completed", conclusion: "success"});
    }
    checkRuns.push({name: validation.checkName, head_sha: headSha, status: "completed", conclusion: "success", app: {slug: "github-actions"}, run_id: runId});
  }
  return {policy, context, headSha, checkRuns, workflowRuns, jobs, ...overrides};
};

test("loads and validates the complete base-owned policy matrix", () => {
  assert.equal(validatePolicy(policy).valid, true);
  assert.equal(policy.validations.length, 14);
  assert.ok(policy.validations.every(validation => validation.pullRequestTypes.length === policy.pullRequestEvents.length));
  assert.deepEqual(policy.excludedAutomation, [
    "Release",
    "Stale",
    "Dependabot Auto-merge",
    "Screenshot publication",
    "Post-merge publication",
    "Scheduled maintenance",
    "Manual-only validation",
  ]);
});

test("rejects missing, conflicting, and unknown policy data", () => {
  assert.equal(validatePolicy({...policy, version: 2}).valid, false);
  assert.match(validatePolicy({...policy, validations: [...policy.validations, policy.validations[0]]}).errors.join(" "), /Duplicate validation id/u);
  assert.match(validatePolicy({...policy, validations: policy.validations.map(validation => validation.id === "unit-tests" ? {...validation, checkName: "PR Description Check"} : validation)}).errors.join(" "), /Duplicate validation check name/u);
  assert.match(validatePolicy({...policy, validations: policy.validations.map(validation => validation.id === "unit-tests" ? {...validation, prerequisites: ["missing"]} : validation)}).errors.join(" "), /Unknown prerequisite/u);
  assert.match(validatePolicy({...policy, validations: [policy.validations.find(validation => validation.id === "unit-tests"), ...policy.validations.filter(validation => validation.id !== "unit-tests")]}).errors.join(" "), /must precede/u);
  assert.match(validatePolicy({...policy, validations: policy.validations.map(validation => validation.id === "unit-tests" ? {...validation, pullRequestTypes: ["opened"]} : validation)}).errors.join(" "), /trigger types/u);
  assert.match(validatePolicy({...policy, validations: policy.validations.map(validation => validation.id === "unit-tests" ? {...validation, applicability: {...validation.applicability, categories: ["missing"]}} : validation)}).errors.join(" "), /Unknown changed category/u);
  assert.equal(validatePolicy({...policy, expectedIntegration: "candidate"}).valid, false);
});

test("classifies source, tests, resources, package, build, toolchain, enforcement, and documentation paths", () => {
  const assessment = classifyChangedFiles(policy, [
    "Sources/AgentSessionManager/Models/AppState.swift",
    "Sources/Resources/icon.pdf",
    "Sources/AgentSessionManager/Resources/Assets.xcassets/icon.pdf",
    "Tests/AppStateTests.swift",
    "UITests/LaunchTests.swift",
    "Package.swift",
    "project.yml",
    "Makefile",
    "scripts/check-toolchain.sh",
    ".github/workflows/ci.yml",
    "documentation/how-to/ci.md",
  ]);
  assert.deepEqual(assessment.categories, ["source", "resources", "tests", "ui-tests", "package", "project", "build", "enforcement", "documentation"]);
  assert.equal(assessment.macOSApplicable, true);
  assert.deepEqual(assessment.unknownPaths, []);
});

test("allows only the explicit documentation allowlist to be macOS non-applicable", () => {
  const assessment = classifyChangedFiles(policy, ["documentation/how-to/ci.md", "README.md"]);
  assert.equal(assessment.macOSApplicable, false);
  assert.equal(assessment.notApplicableReason, "all changed paths are in the trusted macOS allowlist");
  assert.equal(classifyChangedFiles(policy, ["unknown.bin"]).macOSApplicable, true);
  assert.match(classifyChangedFiles(policy, ["unknown.bin"]).errors.join(" "), /Unknown changed path/u);
  assert.match(classifyChangedFiles(policy, ["documentation/../Sources/App.swift"]).errors.join(" "), /unsafe path/u);
  assert.match(classifyChangedFiles(policy, ["documentation\\App.md"]).errors.join(" "), /unsafe path/u);
});

test("fails closed for incomplete, truncated, and over-ceiling changed-file manifests", () => {
  assert.equal(classifyChangedFiles(policy, ["Sources/App.swift"], false).complete, false);
  assert.match(classifyChangedFiles(policy, ["Sources/App.swift"], false).errors.join(" "), /incomplete/u);
  const files = Array.from({length: policy.maxChangedFiles + 1}, (_, index) => `Sources/File${index}.swift`);
  assert.match(classifyChangedFiles(policy, files).errors.join(" "), /ceiling/u);
});

test("assembles complete paginated manifests and rejects truncation boundaries", () => {
  const pages = [{files: ["documentation/one.md", "documentation/two.md"], hasNextPage: true}, {files: ["README.md"], hasNextPage: false}];
  assert.deepEqual(assembleChangedFileManifest(pages, {pageSize: 2}), {files: ["documentation/one.md", "documentation/two.md", "README.md"], complete: true, errors: []});
  const truncated = assembleChangedFileManifest([{files: ["documentation/one.md", "documentation/two.md"], hasNextPage: undefined}], {pageSize: 2});
  assert.equal(truncated.complete, false);
  assert.match(truncated.errors.join(" "), /metadata/u);
  const advertised = assembleChangedFileManifest([{files: ["README.md"], hasNextPage: true}], {pageSize: 2});
  assert.equal(advertised.complete, false);
  assert.equal(assembleChangedFileManifest([["README.md"]], {pageSize: 2}).complete, false);
});

test("parses exact true and false while treating missing and malformed values as enabled", () => {
  assert.deepEqual(parseMacOSPolicy("false"), {enabled: false, state: "disabled-policy", reason: "ENABLE_MACOSX_JOBS is exactly false"});
  assert.equal(parseMacOSPolicy("true").enabled, true);
  assert.equal(parseMacOSPolicy(undefined).enabled, true);
  assert.equal(parseMacOSPolicy("FALSE").enabled, true);
});

test("covers fork, draft, edited, and candidate workflow-policy fixture context", () => {
  const fork = expectedValidations(policy, contextFor(["Sources/App.swift"], "true", "contributor/example")).find(validation => validation.id === "openspec-guide");
  assert.equal(fork.state, "not-applicable");
  const draftEdited = expectedValidations(policy, contextFor(["documentation/ci.md"], "true"));
  assert.equal(draftEdited.find(validation => validation.id === "pr-description").state, "waiting");
  assert.equal(draftEdited.find(validation => validation.id === "unit-tests").state, "not-applicable");
  for (const event of policy.pullRequestEvents) assert.equal(expectedValidations(policy, {...contextFor(["documentation/ci.md"]), event}).length, policy.validations.length);
  const candidateWorkflowEdit = expectedValidations(policy, contextFor([".github/workflows/unit-tests.yml"]));
  assert.equal(candidateWorkflowEdit.find(validation => validation.id === "unit-tests").state, "waiting");
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "agent-session-manager-ci-gate-candidate-"));
  fs.mkdirSync(path.join(temporary, ".github"), {recursive: true});
  fs.writeFileSync(path.join(temporary, ".github", "ci-gate-policy.json"), JSON.stringify({...policy, validations: policy.validations.slice(0, -1)}));
  assert.equal(loadPolicy(root).validations.length, 14);
  assert.equal(loadPolicy(temporary).validations.length, 13);
  assert.equal(expectedValidations(loadPolicy(root), contextFor([".github/workflows/unit-tests.yml"])).length, 14);
  const trustedResult = createTrustedEvaluator(root)(completedEvidence(contextFor([".github/workflows/unit-tests.yml"])));
  assert.equal(trustedResult.validations.length, 14);
});

test("returns success only when every applicable current-head validation has exact provenance", () => {
  const result = evaluateGate(completedEvidence(contextFor(["documentation/ci.md"]), {headSha}));
  assert.equal(result.decision, "success");
  assert.ok(result.validations.every(validation => ["passed", "not-applicable"].includes(validation.state)));
});

test("classifies missing, waiting, failed, skipped, cancelled, timed-out, and neutral results", () => {
  const context = contextFor(["documentation/ci.md"]);
  const evidence = completedEvidence(context);
  const target = evidence.checkRuns.find(check => check.name === "PR Description Check");
  for (const [conclusion, expected] of [["failure", "failed"], ["skipped", "skipped"], ["cancelled", "cancelled"], ["timed_out", "timed-out"], ["neutral", "neutral"]]) {
    const result = evaluateGate({...evidence, checkRuns: evidence.checkRuns.map(check => check.name === target.name ? {...check, conclusion} : check)});
    assert.equal(result.validations.find(validation => validation.id === "pr-description").state, expected);
  }
  const waiting = evaluateGate({...evidence, checkRuns: evidence.checkRuns.map(check => check.name === target.name ? {...check, conclusion: null, status: "in_progress"} : check)});
  assert.equal(waiting.validations.find(validation => validation.id === "pr-description").state, "waiting");
  const timedOut = evaluateGate({...evidence, checkRuns: [], workflowRuns: [], jobs: [], timedOut: true});
  assert.equal(timedOut.validations.find(validation => validation.id === "pr-description").state, "timed-out");
  const missing = evaluateGate({...evidence, checkRuns: [], workflowRuns: [], jobs: []});
  assert.equal(missing.validations.find(validation => validation.id === "pr-description").state, "waiting");
});

test("rejects stale heads, duplicate names, and unexpected integrations", () => {
  const context = contextFor(["documentation/ci.md"]);
  const evidence = completedEvidence(context);
  const target = evidence.checkRuns.find(check => check.name === "PR Description Check");
  assert.equal(evaluateGate({...evidence, checkRuns: evidence.checkRuns.map(check => check.name === target.name ? {...check, head_sha: "c".repeat(40)} : check)}).validations.find(validation => validation.id === "pr-description").state, "stale");
  assert.equal(evaluateGate({...evidence, checkRuns: [...evidence.checkRuns, target]}).validations.find(validation => validation.id === "pr-description").state, "failed");
  assert.match(evaluateGate({...evidence, checkRuns: evidence.checkRuns.map(check => check.name === target.name ? {...check, app: {slug: "circleci"}} : check)}).validations.find(validation => validation.id === "pr-description").reason, /unexpected integration/u);
});

test("requires exact workflow and job provenance rather than a display-name collision", () => {
  const context = contextFor(["documentation/ci.md"]);
  const evidence = completedEvidence(context);
  const target = evidence.checkRuns.find(check => check.name === "PR Description Check");
  const wrongWorkflow = evaluateGate({...evidence, workflowRuns: evidence.workflowRuns.map(run => run.id === target.run_id ? {...run, name: "Untrusted workflow"} : run)});
  assert.equal(wrongWorkflow.validations.find(validation => validation.id === "pr-description").state, "missing");
  const wrongJob = evaluateGate({...evidence, jobs: evidence.jobs.map(job => job.run_id === target.run_id ? {...job, name: "collision"} : job)});
  assert.equal(wrongJob.validations.find(validation => validation.id === "pr-description").state, "missing");
  const wrongPath = evaluateGate({...evidence, workflowRuns: evidence.workflowRuns.map(run => run.id === target.run_id ? {...run, path: ".github/workflows/untrusted.yml"} : run)});
  assert.equal(wrongPath.validations.find(validation => validation.id === "pr-description").state, "failed");
  const staleJob = evaluateGate({...evidence, jobs: evidence.jobs.map(job => job.run_id === target.run_id ? {...job, head_sha: "c".repeat(40)} : job)});
  assert.equal(staleJob.validations.find(validation => validation.id === "pr-description").state, "stale");
  const unrelatedSameName = evaluateGate({...evidence, checkRuns: evidence.checkRuns.map(check => check.name === target.name ? {...check, run_id: undefined} : check)});
  assert.equal(unrelatedSameName.validations.find(validation => validation.id === "pr-description").state, "failed");
  const otherPullRequest = evaluateGate({...evidence, workflowRuns: evidence.workflowRuns.map(run => run.id === target.run_id ? {...run, pull_request_number: 999} : run)});
  assert.equal(otherPullRequest.validations.find(validation => validation.id === "pr-description").state, "stale");
  const spoofedIntegration = evaluateGate({...evidence, checkRuns: evidence.checkRuns.map(check => check.name === target.name ? {...check, app: {name: "GitHub Actions"}} : check)});
  assert.equal(spoofedIntegration.validations.find(validation => validation.id === "pr-description").state, "failed");
});

test("reports disabled macOS policy without treating it as a test pass", () => {
  const context = contextFor(["Sources/App.swift"], "false");
  const result = evaluateGate(completedEvidence(context));
  const unit = result.validations.find(validation => validation.id === "unit-tests");
  assert.equal(unit.state, "disabled-policy");
  assert.equal(result.decision, "success");
  assert.equal(result.macOSPolicy.enabled, false);
});

test("requires macOS for missing and malformed policy variables", () => {
  for (const value of [undefined, "FALSE", "yes"]) {
    const context = contextFor(["Sources/App.swift"], value);
    const evidence = completedEvidence(context);
    const macOSValidations = expectedValidations(policy, context).filter(validation => validation.macOS === true);
    const macOSCheckNames = new Set(macOSValidations.map(validation => validation.checkName));
    const macOSWorkflowNames = new Set(macOSValidations.map(validation => validation.workflowName));
    const result = evaluateGate({
      ...evidence,
      checkRuns: evidence.checkRuns.filter(check => !macOSCheckNames.has(check.name)),
      workflowRuns: evidence.workflowRuns.filter(run => !macOSWorkflowNames.has(run.name)),
    });
    assert.equal(result.validations.find(validation => validation.id === "unit-tests").state, "waiting");
  }
});

test("blocks expensive validations after a failed prerequisite", () => {
  const context = contextFor(["Sources/App.swift"]);
  const evidence = completedEvidence(context);
  const result = evaluateGate({...evidence, checkRuns: evidence.checkRuns.map(check => check.name === "swift-format check" ? {...check, conclusion: "failure"} : check)});
  assert.equal(result.validations.find(validation => validation.id === "swift-format").state, "failed");
  assert.equal(result.validations.find(validation => validation.id === "unit-tests").state, "prerequisite-blocked");
  assert.equal(result.decision, "failure");
});

test("fails closed when policy or changed-file input is invalid", () => {
  const context = {...contextFor(["Sources/App.swift"]), changedFiles: classifyChangedFiles(policy, ["Sources/App.swift"], false)};
  const result = evaluateGate(completedEvidence(context));
  assert.equal(result.decision, "failure");
  assert.match(result.policyErrors.join(" "), /incomplete/u);
  assert.equal(evaluateGate({...completedEvidence(context), policy: {...policy, version: 99}}).decision, "failure");
  const missingFiles = evaluateGate(completedEvidence(context, {context: {...context, changedFiles: undefined}}));
  assert.equal(missingFiles.decision, "failure");
  assert.match(missingFiles.policyErrors.join(" "), /assessment is missing/u);
  const missingHead = evaluateGate(completedEvidence(context, {headSha: undefined}));
  assert.equal(missingHead.decision, "failure");
  assert.match(missingHead.validations.find(validation => validation.id === "pr-description").reason, /head SHA is missing/u);
  const missingIdentity = evaluateGate({...completedEvidence(context), context: {...context, baseSha: undefined, pullRequestNumber: undefined, event: undefined}});
  assert.equal(missingIdentity.decision, "failure");
  assert.match(missingIdentity.policyErrors.join(" "), /base SHA|pull-request number|event/u);
  const malformedApplicability = evaluateGate({...completedEvidence(context), policy: {...policy, validations: policy.validations.map(validation => validation.id === "pr-description" ? {...validation, applicability: null} : validation)}});
  assert.equal(malformedApplicability.decision, "failure");
  const unsupportedEvent = evaluateGate({...completedEvidence(context), context: {...context, event: "deleted"}});
  assert.equal(unsupportedEvent.decision, "failure");
  assert.match(unsupportedEvent.policyErrors.join(" "), /unsupported/u);
});

test("exposes every contract terminal state", () => {
  for (const state of ["passed", "failed", "waiting", "missing", "skipped", "cancelled", "timed-out", "neutral", "stale", "not-applicable", "prerequisite-blocked", "disabled-policy"]) assert.equal(terminalStates.has(state), true);
});
