import fs from "node:fs";
import process from "node:process";

import {GitHubActionsAPI} from "./ci-gate-api.mjs";
import {createTrustedEvaluator, loadPolicy, renderDiagnosticSummary} from "./ci-gate-evaluator.mjs";

const shaPattern = /^[0-9a-f]{40}$/iu;

const requiredEnvironment = (environment, name) => {
  const value = environment[name];
  if (!value) throw new Error(`${name} is unavailable.`);
  return value;
};

const writeFile = (filename, content) => {
  if (filename) fs.appendFileSync(filename, `${content}\n`);
};

const publishResult = (result, environment) => {
  writeFile(environment.GITHUB_STEP_SUMMARY, renderDiagnosticSummary(result));
  writeFile(environment.GITHUB_OUTPUT, `decision=${result.decision}`);
};

const publishFailure = (error, environment = process.env) => {
  const summary = renderDiagnosticSummary({
    decision: "failure",
    policySourceSHA: environment.CI_GATE_POLICY_SHA,
    policyErrors: [error.message],
    validations: [],
  });
  writeFile(environment.GITHUB_STEP_SUMMARY, summary);
  writeFile(environment.GITHUB_OUTPUT, "decision=failure");
};

const wait = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

export async function runGate({environment = process.env, fetchImplementation = fetch, sleep = wait} = {}) {
  const policyRoot = requiredEnvironment(environment, "CI_GATE_POLICY_ROOT");
  const policySourceSHA = requiredEnvironment(environment, "CI_GATE_POLICY_SHA");
  if (!shaPattern.test(policySourceSHA)) throw new Error("CI_GATE_POLICY_SHA is malformed.");
  const token = requiredEnvironment(environment, "GITHUB_TOKEN");
  const repository = requiredEnvironment(environment, "GITHUB_REPOSITORY");
  const pullRequestNumber = Number(requiredEnvironment(environment, "PR_NUMBER"));
  if (!Number.isInteger(pullRequestNumber) || pullRequestNumber < 1) throw new Error("PR_NUMBER is malformed.");
  const [owner, repo] = repository.split("/");
  if (!owner || !repo || repository.split("/").length !== 2) throw new Error("GITHUB_REPOSITORY is malformed.");
  const policy = loadPolicy(policyRoot);
  const evaluateTrustedGate = input => ({...createTrustedEvaluator(policyRoot)(input), policySourceSHA});
  const api = new GitHubActionsAPI({token, fetchImplementation});
  const timeoutMs = Number(environment.CI_GATE_TIMEOUT_MS ?? 10 * 60 * 1000);
  const pollMs = Number(environment.CI_GATE_POLL_MS ?? 20 * 1000);
  const startedAt = Date.now();
  let timedOut = false;
  let result;
  while (true) {
    const input = await api.collectGateInput({owner, repo, pullRequestNumber, policy});
    const currentPullRequest = await api.getPullRequest(owner, repo, pullRequestNumber);
    if (currentPullRequest.head.sha !== input.context.headSha) {
      result = {decision: "failure", headSha: input.context.headSha, policyVersion: policy.version, policySourceSHA, expectedIntegration: policy.expectedIntegration, policyErrors: ["Pull-request head advanced while the gate was evaluating; this result is obsolete."], macOSPolicy: {enabled: true, state: "enabled", reason: "superseded revision"}, validations: []};
      break;
    }
    input.context.event = environment.PR_EVENT ?? "synchronize";
    result = evaluateTrustedGate({context: input.context, checkRuns: input.checkRuns, workflowRuns: input.workflowRuns, jobs: input.jobs, headSha: input.context.headSha, timedOut: false});
    if (result.decision === "success" || result.validations.some(validation => ["failed", "skipped", "cancelled", "timed-out", "neutral", "stale", "prerequisite-blocked"].includes(validation.state)) || Date.now() - startedAt >= timeoutMs) {
      if (result.decision !== "success" && Date.now() - startedAt >= timeoutMs) {
        timedOut = true;
        result = evaluateTrustedGate({context: input.context, checkRuns: input.checkRuns, workflowRuns: input.workflowRuns, jobs: input.jobs, headSha: input.context.headSha, timedOut});
      }
      break;
    }
    await sleep(pollMs);
  }
  const finalInput = await api.collectGateInput({owner, repo, pullRequestNumber, policy});
  const finalPullRequest = await api.getPullRequest(owner, repo, pullRequestNumber);
  if (finalPullRequest.head.sha !== finalInput.context.headSha || finalInput.context.headSha !== result.headSha) {
    result = {decision: "failure", headSha: result.headSha, policyVersion: policy.version, policySourceSHA, expectedIntegration: policy.expectedIntegration, policyErrors: ["Pull-request head advanced immediately before publication; this result is obsolete."], macOSPolicy: {enabled: true, state: "enabled", reason: "superseded revision"}, validations: []};
  } else {
    finalInput.context.event = environment.PR_EVENT ?? "synchronize";
    result = evaluateTrustedGate({context: finalInput.context, checkRuns: finalInput.checkRuns, workflowRuns: finalInput.workflowRuns, jobs: finalInput.jobs, headSha: finalInput.context.headSha, timedOut});
  }
  publishResult(result, environment);
  const publishedPullRequest = await api.getPullRequest(owner, repo, pullRequestNumber);
  if (publishedPullRequest.head.sha !== result.headSha) {
    result = {decision: "failure", headSha: result.headSha, policyVersion: policy.version, policySourceSHA, expectedIntegration: policy.expectedIntegration, policyErrors: ["Pull-request head advanced during publication; the published result is obsolete."], macOSPolicy: {enabled: true, state: "enabled", reason: "superseded revision"}, validations: []};
    publishResult(result, environment);
  }
  return result;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runGate().catch(error => {
    publishFailure(error);
    process.exitCode = 1;
  }).then(result => {
    if (result?.decision === "failure") process.exitCode = 1;
  });
}
