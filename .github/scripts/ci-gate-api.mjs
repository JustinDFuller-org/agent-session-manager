import {assembleChangedFileManifest, classifyChangedFiles} from "./ci-gate-evaluator.mjs";

const defaultPageSize = 100;

const withPage = (endpoint, page, pageSize) => {
  const url = new URL(endpoint, "https://api.github.com");
  url.searchParams.set("page", String(page));
  url.searchParams.set("per_page", String(pageSize));
  return url.pathname + url.search;
};

const hasNextPage = response => /[?&]page=\d+[^>]*>;\s*rel="next"/u.test(response.headers.get("link") ?? "");

export class GitHubActionsAPI {
  constructor({token, fetchImplementation = fetch, baseURL = "https://api.github.com"} = {}) {
    this.token = token;
    this.fetchImplementation = fetchImplementation;
    this.baseURL = baseURL;
  }

  async request(endpoint) {
    if (!this.token) throw new Error("GITHUB_TOKEN is unavailable.");
    const response = await this.fetchImplementation(new URL(endpoint, this.baseURL), {
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${this.token}`,
        "X-GitHub-Api-Version": "2022-11-28",
      },
    });
    if (!response.ok) throw new Error(`GitHub API request failed with HTTP ${response.status}.`);
    return response;
  }

  async getJSON(endpoint) {
    return (await this.request(endpoint)).json();
  }

  async paginate(endpoint, property, {pageSize = defaultPageSize, maxItems = 3000} = {}) {
    const pages = [];
    let page = 1;
    while (true) {
      const response = await this.request(withPage(endpoint, page, pageSize));
      const body = await response.json();
      const items = body[property];
      if (!Array.isArray(items)) throw new Error(`GitHub API response is missing the ${property} collection.`);
      const nextPage = hasNextPage(response);
      if (!nextPage && items.length === pageSize) throw new Error(`GitHub API ${property} collection ended at the page-size boundary and may be truncated.`);
      pages.push({files: items, hasNextPage: nextPage});
      if (items.length > maxItems || pages.flatMap(currentPage => currentPage.files).length > maxItems) throw new Error(`GitHub API pagination exceeded the supported ceiling of ${maxItems}.`);
      if (!nextPage) break;
      page += 1;
      if (page > Math.ceil(maxItems / pageSize)) throw new Error(`GitHub API pagination exceeded the supported page count for ${maxItems} items.`);
    }
    return pages;
  }

  async getPullRequest(owner, repo, pullRequestNumber) {
    return this.getJSON(`/repos/${owner}/${repo}/pulls/${pullRequestNumber}`);
  }

  async getRepositoryVariable(owner, repo, variableName) {
    try {
      return {value: (await this.getJSON(`/repos/${owner}/${repo}/actions/variables/${variableName}`)).value, error: null};
    } catch (error) {
      if (String(error.message).includes("HTTP 404")) return {value: undefined, error: null};
      return {value: undefined, error: "repository variable could not be read; macOS validation remains enabled"};
    }
  }

  async getCheckRuns(owner, repo, headSha) {
    const pages = await this.paginate(`/repos/${owner}/${repo}/commits/${headSha}/check-runs`, "check_runs");
    return pages.flatMap(page => page.files);
  }

  async getWorkflowRuns(owner, repo, headSha, pullRequestNumber) {
    const pages = await this.paginate(`/repos/${owner}/${repo}/actions/runs?head_sha=${encodeURIComponent(headSha)}`, "workflow_runs");
    return pages.flatMap(page => page.files)
      .filter(run => run.pull_requests?.some(pullRequest => pullRequest.number === pullRequestNumber))
      .map(run => ({...run, pull_request_number: pullRequestNumber}));
  }

  async getJobs(owner, repo, runIDs) {
    const jobs = [];
    for (const runID of runIDs) {
      const pages = await this.paginate(`/repos/${owner}/${repo}/actions/runs/${runID}/jobs`, "jobs");
      jobs.push(...pages.flatMap(page => page.files));
    }
    return jobs;
  }

  async collectGateInput({owner, repo, pullRequestNumber, policy}) {
    const pullRequest = await this.getPullRequest(owner, repo, pullRequestNumber);
    const changedPages = await this.paginate(`/repos/${owner}/${repo}/pulls/${pullRequestNumber}/files`, "files", {maxItems: policy.maxChangedFiles});
    const manifest = assembleChangedFileManifest(changedPages, {maxChangedFiles: policy.maxChangedFiles});
    const changedFiles = classifyChangedFiles(policy, manifest.files.map(file => file.filename), manifest.complete);
    const [variable, checkRuns, workflowRuns] = await Promise.all([
      this.getRepositoryVariable(owner, repo, policy.macOS.variable),
      this.getCheckRuns(owner, repo, pullRequest.head.sha),
      this.getWorkflowRuns(owner, repo, pullRequest.head.sha, pullRequestNumber),
    ]);
    const jobs = await this.getJobs(owner, repo, workflowRuns.map(run => run.id));
    return {
      context: {
        repositoryFullName: `${owner}/${repo}`,
        headRepositoryFullName: pullRequest.head.repo?.full_name,
        baseSha: pullRequest.base.sha,
        headSha: pullRequest.head.sha,
        pullRequestNumber,
        draft: pullRequest.draft === true,
        event: "synchronize",
        macOSVariable: variable.value,
        macOSVariableError: variable.error,
        changedFiles,
      },
      checkRuns,
      workflowRuns,
      jobs,
      variableError: variable.error,
    };
  }
}

export {defaultPageSize};
