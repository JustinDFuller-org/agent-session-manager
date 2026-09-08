import fs from "node:fs";
import path from "node:path";

const supportedPolicyVersion = 1;
const terminalStates = new Set([
  "passed",
  "failed",
  "waiting",
  "missing",
  "skipped",
  "cancelled",
  "timed-out",
  "neutral",
  "stale",
  "not-applicable",
  "prerequisite-blocked",
  "disabled-policy",
]);

const terminalFailureStates = new Set([
  "failed",
  "missing",
  "skipped",
  "cancelled",
  "timed-out",
  "neutral",
  "stale",
  "prerequisite-blocked",
]);

const globPattern = pattern => {
  const escape = value => value.replace(/[.+^${}()|[\]\\]/g, "\\$&").replaceAll("*", "[^/]*");
  const segments = pattern.split("/");
  let expression = "^";
  segments.forEach((segment, index) => {
    const last = index === segments.length - 1;
    if (segment === "**") expression += last ? ".*" : "(?:[^/]+/)*";
    else {
      expression += escape(segment);
      if (!last) expression += "/";
    }
  });
  return new RegExp(`${expression}$`, "u");
};

const matchesAny = (value, patterns) => patterns.some(pattern => globPattern(pattern).test(value));
const shaPattern = /^[0-9a-f]{40}$/iu;
const validSha = value => typeof value === "string" && shaPattern.test(value);

const validationIdentity = validation => ({
  checkName: validation.checkName,
  workflowName: validation.workflowName,
  workflowFile: validation.workflowFile,
  jobName: validation.jobName,
  event: validation.event,
});

const invalid = errors => ({valid: false, errors});

export function validatePolicy(policy) {
  const errors = [];
  if (policy === null || typeof policy !== "object" || Array.isArray(policy)) {
    return invalid(["Policy must be an object."]);
  }
  if (policy.version !== supportedPolicyVersion) errors.push(`Unsupported policy version: ${String(policy.version)}.`);
  if (!Number.isInteger(policy.maxChangedFiles) || policy.maxChangedFiles < 1) errors.push("maxChangedFiles must be a positive integer.");
  if (policy.expectedIntegration !== "github-actions") errors.push("expectedIntegration must be github-actions.");
  if (!Array.isArray(policy.pullRequestEvents) || policy.pullRequestEvents.length === 0) errors.push("pullRequestEvents must be non-empty.");
  if (!Array.isArray(policy.workflowEvents) || policy.workflowEvents.length === 0) errors.push("workflowEvents must be non-empty.");
  if (!policy.macOS || typeof policy.macOS !== "object") errors.push("macOS policy data is missing.");
  if (!policy.macOS?.variable) errors.push("macOS variable is missing.");
  if (!Array.isArray(policy.macOS?.nonApplicableAllowlist)) errors.push("macOS non-applicable allowlist is missing.");
  if (!policy.pathCategories || typeof policy.pathCategories !== "object") errors.push("pathCategories are missing.");
  if (!Array.isArray(policy.validations) || policy.validations.length === 0) errors.push("validations must be non-empty.");
  if (!Array.isArray(policy.excludedAutomation)) errors.push("excludedAutomation is missing.");
  for (const [name, values] of Object.entries({pullRequestEvents: policy.pullRequestEvents, workflowEvents: policy.workflowEvents, excludedAutomation: policy.excludedAutomation, macOSAllowlist: policy.macOS?.nonApplicableAllowlist})) {
    if (Array.isArray(values) && values.some(value => typeof value !== "string" || value.length === 0)) errors.push(`${name} contains an invalid value.`);
  }
  for (const [category, patterns] of Object.entries(policy.pathCategories ?? {})) {
    if (!Array.isArray(patterns) || patterns.length === 0 || patterns.some(pattern => typeof pattern !== "string" || pattern.length === 0)) errors.push(`Path category ${category} has invalid patterns.`);
  }

  const ids = new Set();
  const checkNames = new Set();
  const identities = new Set();
  const categoryNames = new Set(Object.keys(policy.pathCategories ?? {}));
  for (const validation of policy.validations ?? []) {
    if (!validation || typeof validation !== "object") {
      errors.push("Validation entry must be an object.");
      continue;
    }
    for (const field of ["id", "checkName", "workflowName", "workflowFile", "jobName", "event", "pullRequestTypes", "applicability"]) {
      if (!validation[field]) errors.push(`Validation entry is missing ${field}.`);
    }
    if (ids.has(validation.id)) errors.push(`Duplicate validation id: ${validation.id}.`);
    ids.add(validation.id);
    if (checkNames.has(validation.checkName)) errors.push(`Duplicate validation check name: ${validation.checkName}.`);
    checkNames.add(validation.checkName);
    const identity = JSON.stringify(validationIdentity(validation));
    if (identities.has(identity)) errors.push(`Duplicate validation identity: ${identity}.`);
    identities.add(identity);
    const kind = validation.applicability?.kind;
    if (!["every", "same-repository", "changed-categories"].includes(kind)) errors.push(`Unknown applicability kind for ${validation.id}.`);
    if (kind === "changed-categories" && (!Array.isArray(validation.applicability.categories) || validation.applicability.categories.length === 0)) errors.push(`Changed categories are missing for ${validation.id}.`);
    for (const category of validation.applicability?.categories ?? []) {
      if (!categoryNames.has(category)) errors.push(`Unknown changed category ${category} for ${validation.id}.`);
    }
    if (validation.macOS === true && kind !== "changed-categories") errors.push(`macOS validation ${validation.id} must use changed-categories applicability.`);
    if (validation.prerequisites && !Array.isArray(validation.prerequisites)) errors.push(`Prerequisites must be an array for ${validation.id}.`);
    if (Array.isArray(policy.workflowEvents) && !policy.workflowEvents.includes(validation.event)) errors.push(`Validation event ${validation.event} is not declared by workflowEvents.`);
    if (Array.isArray(policy.pullRequestEvents) && (!Array.isArray(validation.pullRequestTypes) || validation.pullRequestTypes.some(event => !policy.pullRequestEvents.includes(event)) || policy.pullRequestEvents.some(event => !validation.pullRequestTypes.includes(event)))) errors.push(`Validation pull-request trigger types are missing or unknown for ${validation.id}.`);
  }
  for (const validation of policy.validations ?? []) {
    for (const prerequisite of validation.prerequisites ?? []) {
      if (!ids.has(prerequisite)) errors.push(`Unknown prerequisite ${prerequisite} for ${validation.id}.`);
    }
  }
  const seen = new Set();
  for (const validation of policy.validations ?? []) {
    for (const prerequisite of validation.prerequisites ?? []) {
      if (!seen.has(prerequisite)) errors.push(`Prerequisite ${prerequisite} must precede ${validation.id}.`);
    }
    seen.add(validation.id);
  }
  const visiting = new Set();
  const visited = new Set();
  const visit = id => {
    if (visiting.has(id)) {
      errors.push(`Cyclic prerequisite relationship includes ${id}.`);
      return;
    }
    if (visited.has(id)) return;
    visiting.add(id);
    const validation = (policy.validations ?? []).find(entry => entry.id === id);
    for (const prerequisite of validation?.prerequisites ?? []) visit(prerequisite);
    visiting.delete(id);
    visited.add(id);
  };
  for (const validation of policy.validations ?? []) visit(validation.id);
  return errors.length === 0 ? {valid: true, errors: []} : invalid(errors);
}

export function loadPolicy(root) {
  const policyPath = path.join(root, ".github", "ci-gate-policy.json");
  const policy = JSON.parse(fs.readFileSync(policyPath, "utf8"));
  const validation = validatePolicy(policy);
  if (!validation.valid) throw new Error(validation.errors.join(" "));
  return policy;
}

export function createTrustedEvaluator(enforcementRoot) {
  const policy = loadPolicy(enforcementRoot);
  return input => evaluateGate({...input, policy});
}

const pathCategory = (policy, filename) => {
  for (const [category, patterns] of Object.entries(policy.pathCategories ?? {})) {
    if (Array.isArray(patterns) && matchesAny(filename, patterns)) return category;
  }
  return null;
};

export function classifyChangedFiles(policy, filenames, complete = true) {
  const errors = [];
  if (!complete) errors.push("Changed-file manifest is incomplete.");
  if (!Array.isArray(filenames)) errors.push("Changed-file manifest is not an array.");
  const files = Array.isArray(filenames) ? filenames : [];
  if (files.length === 0) errors.push("Changed-file manifest is empty.");
  if (files.length > policy.maxChangedFiles) errors.push(`Changed-file manifest exceeds the supported ceiling of ${policy.maxChangedFiles}.`);
  if (!Array.isArray(policy.macOS?.nonApplicableAllowlist)) errors.push("macOS non-applicable allowlist is missing.");
  const categories = new Map();
  const unknownPaths = [];
  for (const filename of files) {
    if (typeof filename !== "string" || filename.length === 0) {
      errors.push("Changed-file manifest contains an invalid path.");
      continue;
    }
    if (filename.startsWith("/") || filename.includes("\\") || filename.split("/").some(segment => segment.length === 0 || segment === "." || segment === "..")) {
      errors.push(`Changed-file manifest contains an unsafe path: ${filename}.`);
      continue;
    }
    const category = pathCategory(policy, filename);
    if (!category) unknownPaths.push(filename);
    else categories.set(filename, category);
  }
  for (const filename of unknownPaths) errors.push(`Unknown changed path: ${filename}.`);
  const allowlist = Array.isArray(policy.macOS?.nonApplicableAllowlist) ? policy.macOS.nonApplicableAllowlist : [];
  const macOSApplicable = errors.length > 0 || !files.every(filename => matchesAny(filename, allowlist));
  return {
    complete: complete && errors.length === 0,
    categories: [...new Set(categories.values())],
    categoryByPath: Object.fromEntries(categories),
    files,
    macOSApplicable,
    notApplicableReason: macOSApplicable ? null : "all changed paths are in the trusted macOS allowlist",
    unknownPaths,
    errors,
  };
}

export function assembleChangedFileManifest(pages, {pageSize = 100, maxChangedFiles = 3000} = {}) {
  const errors = [];
  if (!Array.isArray(pages) || pages.length === 0) return {files: [], complete: false, errors: ["Changed-file pagination returned no pages."]};
  const files = [];
  pages.forEach((page, index) => {
    const pageFiles = Array.isArray(page) ? page : page?.files;
    const hasNextPage = Array.isArray(page) ? undefined : page?.hasNextPage;
    if (!Array.isArray(pageFiles)) {
      errors.push(`Changed-file page ${index + 1} is not an array.`);
      return;
    }
    if (hasNextPage !== true && hasNextPage !== false) errors.push(`Changed-file page ${index + 1} is missing explicit pagination metadata.`);
    if (pageFiles.length > pageSize) errors.push(`Changed-file page ${index + 1} exceeds the requested page size.`);
    files.push(...pageFiles);
    if (hasNextPage === true && index === pages.length - 1) errors.push("Changed-file pagination ended before the advertised next page.");
    if (hasNextPage === false && index !== pages.length - 1) errors.push("Changed-file pagination contains pages after its terminal page.");
    if (index === pages.length - 1 && hasNextPage !== false && pageFiles.length === pageSize) errors.push("Changed-file pagination ended at the page-size boundary and may be truncated.");
  });
  if (files.length > maxChangedFiles) errors.push(`Changed-file manifest exceeds the supported ceiling of ${maxChangedFiles}.`);
  return {files, complete: errors.length === 0, errors};
}

export function parseMacOSPolicy(value) {
  if (value === "false") return {enabled: false, state: "disabled-policy", reason: "ENABLE_MACOSX_JOBS is exactly false"};
  if (value === "true") return {enabled: true, state: "enabled", reason: "ENABLE_MACOSX_JOBS is exactly true"};
  return {enabled: true, state: "enabled", reason: value == null ? "ENABLE_MACOSX_JOBS is missing" : "ENABLE_MACOSX_JOBS is malformed"};
}

const sameRepository = context => context.repositoryFullName === context.headRepositoryFullName;

const appliesToContext = (validation, context) => {
  const changedFiles = context.changedFiles;
  const applicability = validation.applicability ?? {kind: "every"};
  if (applicability.kind === "every") return {applies: true, reason: "every gateable pull request"};
  if (applicability.kind === "same-repository") return sameRepository(context)
    ? {applies: true, reason: "same-repository pull request"}
    : {applies: false, reason: "workflow intentionally excludes fork pull requests"};
  const categories = new Set(changedFiles.categories);
  const applicableCategories = Array.isArray(applicability.categories) ? applicability.categories : [];
  const applies = applicableCategories.some(category => categories.has(category)) || changedFiles.macOSApplicable;
  return applies
    ? {applies: true, reason: changedFiles.errors.length > 0 ? "changed-file policy input failed closed" : "changed paths match the trusted applicability categories"}
    : {applies: false, reason: changedFiles.notApplicableReason};
};

export function expectedValidations(policy, context) {
  const macOSPolicy = parseMacOSPolicy(context?.macOSVariable);
  return policy.validations.map(validation => {
    const applicability = appliesToContext(validation, context);
    let state = applicability.applies ? "waiting" : "not-applicable";
    let reason = applicability.reason;
    if (applicability.applies && validation.macOS === true && !macOSPolicy.enabled) {
      state = "disabled-policy";
      reason = macOSPolicy.reason;
    }
    return {
      ...validation,
      state,
      applicabilityReason: reason,
      expected: validationIdentity(validation),
      policyDecision: validation.macOS === true && !macOSPolicy.enabled ? macOSPolicy.state : null,
    };
  });
}

const normalizedIntegration = check => {
  const app = check?.app;
  const value = app !== null && typeof app === "object" ? app.slug : null;
  if (typeof value !== "string") return null;
  return value.toLowerCase().replaceAll(" ", "-");
};

const checkConclusionState = (check, timedOut) => {
  const status = typeof check?.status === "string" ? check.status.toLowerCase() : null;
  const conclusion = typeof check?.conclusion === "string" ? check.conclusion.toLowerCase() : null;
  if (!status) return "failed";
  if (conclusion === "success") return status === "completed" ? "passed" : "failed";
  if (conclusion === "skipped") return "skipped";
  if (conclusion === "cancelled" || conclusion === "canceled") return "cancelled";
  if (conclusion === "timed_out" || conclusion === "timed-out") return "timed-out";
  if (conclusion === "neutral") return "neutral";
  if (conclusion) return "failed";
  if (status === "completed") return "failed";
  if (timedOut) return "timed-out";
  return "waiting";
};

const currentChecks = (checks, expected, headSha) => checks.filter(check => check.name === expected.checkName && check.head_sha === headSha);
const staleChecks = (checks, expected, headSha) => checks.filter(check => check.name === expected.checkName && check.head_sha !== headSha);
const currentRuns = (runs, expected, headSha, pullRequestNumber) => runs.filter(run => run.name === expected.workflowName && run.head_sha === headSha && run.event === expected.event && run.pull_request_number === pullRequestNumber);
const staleRuns = (runs, expected, headSha, pullRequestNumber) => runs.filter(run => run.name === expected.workflowName && (run.head_sha !== headSha || run.pull_request_number !== pullRequestNumber));

const observeValidation = (validation, input) => {
  if (!validSha(input.headSha)) return {state: "failed", reason: "current pull-request head SHA is missing or malformed", observed: null};
  const checks = Array.isArray(input.checkRuns) ? input.checkRuns : [];
  const runs = Array.isArray(input.workflowRuns) ? input.workflowRuns : [];
  const jobs = Array.isArray(input.jobs) ? input.jobs : [];
  const matches = currentChecks(checks, validation, input.headSha);
  const stale = staleChecks(checks, validation, input.headSha);
  if (matches.some(check => check.run_id == null)) return {state: "failed", reason: "check run has no unambiguous workflow-run association", observed: matches};
  if (matches.length === 0) {
    return {
      state: stale.length > 0 ? "stale" : input.timedOut ? "timed-out" : "waiting",
      reason: stale.length > 0 ? "matching check exists only for an earlier head SHA" : input.timedOut ? "no matching check run before the gate timeout" : "no matching check run yet for the current head SHA",
      observed: stale[0] ?? null,
    };
  }
  if (matches.length > 1) return {state: "failed", reason: "duplicate check runs match the expected name and head SHA", observed: matches};
  const check = matches[0];
  if (normalizedIntegration(check) !== input.expectedIntegration) return {state: "failed", reason: "check run has unexpected integration provenance", observed: check};
  const candidateRuns = currentRuns(runs, validation, input.headSha, input.pullRequestNumber);
  const runMatches = check.run_id == null
    ? candidateRuns
    : candidateRuns.filter(run => String(run.id) === String(check.run_id));
  const oldRuns = staleRuns(runs, validation, input.headSha, input.pullRequestNumber);
  if (runMatches.length !== 1) return {state: oldRuns.length > 0 ? "stale" : runMatches.length === 0 ? "missing" : "failed", reason: oldRuns.length > 0 ? "workflow run exists for an earlier head or another pull request" : runMatches.length === 0 ? "workflow run provenance is missing" : "workflow run provenance is ambiguous", observed: check};
  const run = runMatches[0];
  if (run.path !== validation.workflowFile) return {state: "failed", reason: "workflow run has unexpected or missing workflow-file provenance", observed: check};
  if (check.run_id != null && String(check.run_id) !== String(run.id)) return {state: "failed", reason: "check run is attached to an unexpected workflow run", observed: check};
  const jobMatches = jobs.filter(job => String(job.run_id) === String(run.id) && job.name === validation.jobName);
  if (jobMatches.length !== 1) return {state: jobMatches.length === 0 ? "missing" : "failed", reason: jobMatches.length === 0 ? "workflow job provenance is missing" : "workflow job provenance is ambiguous", observed: check};
  if (!validSha(jobMatches[0].head_sha)) return {state: "failed", reason: "workflow job head SHA is missing or malformed", observed: check};
  if (jobMatches[0].head_sha !== input.headSha) return {state: "stale", reason: "workflow job belongs to an earlier head SHA", observed: check};
  const state = checkConclusionState(check, input.timedOut);
  const runState = checkConclusionState(run, input.timedOut);
  const jobState = checkConclusionState(jobMatches[0], input.timedOut);
  if (runState !== "passed") return {state: runState, reason: `workflow run conclusion is ${run.conclusion ?? "not complete"}`, observed: {check, run, job: jobMatches[0]}};
  if (jobState !== "passed") return {state: jobState, reason: `workflow job conclusion is ${jobMatches[0].conclusion ?? "not complete"}`, observed: {check, run, job: jobMatches[0]}};
  return {state, reason: state === "passed" ? "current check, workflow, and job provenance match" : `check conclusion is ${check.conclusion ?? "not complete"}`, observed: {check, run, job: jobMatches[0]}};
};

export function evaluateGate({policy, context, checkRuns = [], workflowRuns = [], jobs = [], headSha, timedOut = false}) {
  const policyValidation = validatePolicy(policy);
  const changedFiles = context?.changedFiles ?? {
    categories: [],
    errors: ["Changed-file assessment is missing."],
    files: [],
    macOSApplicable: true,
    notApplicableReason: null,
  };
  const evaluationContext = {...context, changedFiles};
  const evaluations = Array.isArray(policy?.validations) ? expectedValidations(policy, evaluationContext) : [];
  const results = new Map();
  for (const validation of evaluations) {
    let result = {state: validation.state, reason: validation.applicabilityReason, observed: null};
    if (result.state === "waiting") {
      const prerequisiteStates = (validation.prerequisites ?? []).map(id => results.get(id)?.state);
      if (prerequisiteStates.some(state => terminalFailureStates.has(state))) {
        result = {state: "prerequisite-blocked", reason: `prerequisite failed: ${validation.prerequisites.find(id => terminalFailureStates.has(results.get(id)?.state))}`, observed: null};
      } else if (prerequisiteStates.some(state => state === "waiting" || state === "missing")) {
        result = {state: "waiting", reason: "waiting for prerequisite validation", observed: null};
      } else {
        result = observeValidation(validation, {checkRuns, workflowRuns, jobs, headSha, pullRequestNumber: evaluationContext.pullRequestNumber, timedOut, expectedIntegration: policy.expectedIntegration});
      }
    }
    results.set(validation.id, result);
  }
  const policyErrors = [
    ...(!policyValidation.valid ? policyValidation.errors : []),
    ...(changedFiles?.errors ?? ["Changed-file assessment is missing."]),
    ...(validSha(headSha) ? [] : ["Current pull-request head SHA is missing or malformed."]),
    ...(validSha(evaluationContext?.baseSha) ? [] : ["Pull-request base SHA is missing or malformed."]),
    ...(Number.isInteger(evaluationContext?.pullRequestNumber) && evaluationContext.pullRequestNumber > 0 ? [] : ["Pull-request number is missing or malformed."]),
    ...(policy?.pullRequestEvents?.includes(evaluationContext?.event) ? [] : ["Pull-request event is missing or unsupported."]),
  ];
  const success = policyErrors.length === 0 && evaluations.every(validation => ["passed", "not-applicable", "disabled-policy"].includes(results.get(validation.id).state));
  return {
    decision: success ? "success" : "failure",
    headSha,
    policyVersion: policy?.version,
    policyErrors,
    macOSPolicy: parseMacOSPolicy(evaluationContext?.macOSVariable),
    validations: evaluations.map(validation => ({
      id: validation.id,
      checkName: validation.checkName,
      applicabilityReason: validation.applicabilityReason,
      expected: validation.expected,
      state: results.get(validation.id).state,
      reason: results.get(validation.id).reason,
      observed: results.get(validation.id).observed,
    })),
  };
}

export {terminalStates};
