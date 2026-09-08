import assert from "node:assert/strict";
import test from "node:test";

import {GitHubActionsAPI} from "./ci-gate-api.mjs";
import {loadPolicy} from "./ci-gate-evaluator.mjs";

const policy = loadPolicy(new URL("../..", import.meta.url).pathname);

const response = (body, options = {}) => new Response(JSON.stringify(body), {status: options.status ?? 200, headers: options.headers});

test("paginates API collections and requires a complete terminal page", async () => {
  const requests = [];
  const api = new GitHubActionsAPI({
    token: "test-token",
    fetchImplementation: async url => {
      requests.push(new URL(url).searchParams.get("page"));
      return requests.length === 1
        ? response({items: [{id: 1}, {id: 2}]}, {headers: {link: '<https://api.github.com/items?page=2>; rel="next"'}})
        : response({items: [{id: 3}]});
    },
  });
  const pages = await api.paginate("/items", "items", {pageSize: 2});
  assert.deepEqual(pages.flatMap(page => page.files).map(item => item.id), [1, 2, 3]);
  assert.deepEqual(requests, ["1", "2"]);
});

test("rejects a full terminal page that may hide additional API records", async () => {
  const api = new GitHubActionsAPI({token: "test-token", fetchImplementation: async () => response({items: [{id: 1}]}),});
  await assert.rejects(api.paginate("/items", "items", {pageSize: 1}), /page-size boundary/u);
});

test("reads missing repository variables as enabled-policy input without exposing credentials", async () => {
  const api = new GitHubActionsAPI({token: "test-token", fetchImplementation: async () => response({}, {status: 404})});
  assert.deepEqual(await api.getRepositoryVariable("owner", "repo", "ENABLE_MACOSX_JOBS"), {value: undefined, error: null});
});

test("collects PR identity, complete files, checks, workflow runs, jobs, and trusted variable state", async () => {
  const calls = [];
  const api = new GitHubActionsAPI({
    token: "test-token",
    fetchImplementation: async url => {
      const parsed = new URL(url);
      calls.push(parsed.pathname);
      if (parsed.pathname.endsWith("/pulls/7")) return response({head: {sha: "a".repeat(40), repo: {full_name: "owner/repo"}}, base: {sha: "b".repeat(40)}, draft: true});
      if (parsed.pathname.endsWith("/files")) return response({files: [{filename: "README.md"}]});
      if (parsed.pathname.endsWith("/check-runs")) return response({check_runs: []});
      if (parsed.pathname.endsWith("/actions/variables/ENABLE_MACOSX_JOBS")) return response({value: "false"});
      if (parsed.pathname.endsWith("/actions/runs")) return response({workflow_runs: [
        {id: 8, name: "PR Quality", path: ".github/workflows/pr-quality.yml", head_sha: "a".repeat(40), event: "pull_request", pull_requests: [{number: 7}, {number: 8}]},
        {id: 9, name: "PR Quality", path: ".github/workflows/pr-quality.yml", head_sha: "a".repeat(40), event: "pull_request", pull_requests: [{number: 8}]},
      ]});
      if (parsed.pathname.endsWith("/jobs")) return response({jobs: []});
      throw new Error(`unexpected endpoint ${parsed.pathname}`);
    },
  });
  const input = await api.collectGateInput({owner: "owner", repo: "repo", pullRequestNumber: 7, policy});
  assert.equal(input.context.pullRequestNumber, 7);
  assert.equal(input.context.macOSVariable, "false");
  assert.equal(input.context.changedFiles.macOSApplicable, false);
  assert.deepEqual(input.workflowRuns.map(run => run.id), [8]);
  assert.ok(calls.some(call => call.endsWith("/check-runs")));
});
