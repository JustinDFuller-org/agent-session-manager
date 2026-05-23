---
name: gh-documentation
description: GitHub CLI official doc index — load when building GitHub CLI features, PR/issue automation, API scripting, or any gh CLI behavior.
allowed-tools: WebFetch(domain:cli.github.com)
metadata:
  user-invocable: "false"
---

# GitHub CLI Documentation Index

Fetch from this index before implementing any GitHub CLI feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://cli.github.com/manual/` — Getting started guide and overview.
- `https://cli.github.com/manual/gh` — Main command reference with all top-level commands and global options.

## Core — PR Commands

- `https://cli.github.com/manual/gh_pr` — PR root: create, manage, and review pull requests.
- `https://cli.github.com/manual/gh_pr_checkout` — Check out a PR branch locally.
- `https://cli.github.com/manual/gh_pr_checks` — View CI checks for a PR.
- `https://cli.github.com/manual/gh_pr_close` — Close a PR.
- `https://cli.github.com/manual/gh_pr_comment` — Add a comment to a PR.
- `https://cli.github.com/manual/gh_pr_create` — Create a new PR.
- `https://cli.github.com/manual/gh_pr_diff` — View the diff of a PR.
- `https://cli.github.com/manual/gh_pr_edit` — Edit a PR's metadata (title, body, labels, etc.).
- `https://cli.github.com/manual/gh_pr_list` — List PRs in a repository.
- `https://cli.github.com/manual/gh_pr_lock` — Lock conversation on a PR.
- `https://cli.github.com/manual/gh_pr_merge` — Merge a PR.
- `https://cli.github.com/manual/gh_pr_ready` — Mark a draft PR as ready for review.
- `https://cli.github.com/manual/gh_pr_reopen` — Reopen a closed PR.
- `https://cli.github.com/manual/gh_pr_revert` — Revert a merged PR.
- `https://cli.github.com/manual/gh_pr_review` — Add a review to a PR (approve, request changes, comment).
- `https://cli.github.com/manual/gh_pr_status` — Show CI status for current branch's PRs.
- `https://cli.github.com/manual/gh_pr_unlock` — Unlock conversation on a PR.
- `https://cli.github.com/manual/gh_pr_update-branch` — Update a PR branch with latest base branch.
- `https://cli.github.com/manual/gh_pr_view` — View a PR in browser or terminal.

## Core — Issue Commands

- `https://cli.github.com/manual/gh_issue` — Issue root: create and manage issues.
- `https://cli.github.com/manual/gh_issue_close` — Close an issue.
- `https://cli.github.com/manual/gh_issue_comment` — Add a comment to an issue.
- `https://cli.github.com/manual/gh_issue_create` — Create a new issue.
- `https://cli.github.com/manual/gh_issue_delete` — Delete an issue.
- `https://cli.github.com/manual/gh_issue_develop` — Create a branch from an issue.
- `https://cli.github.com/manual/gh_issue_edit` — Edit an issue's metadata.
- `https://cli.github.com/manual/gh_issue_list` — List issues in a repository.
- `https://cli.github.com/manual/gh_issue_lock` — Lock conversation on an issue.
- `https://cli.github.com/manual/gh_issue_pin` — Pin an issue to the repository.
- `https://cli.github.com/manual/gh_issue_reopen` — Reopen a closed issue.
- `https://cli.github.com/manual/gh_issue_status` — Show status of relevant issues.
- `https://cli.github.com/manual/gh_issue_transfer` — Transfer an issue to another repository.
- `https://cli.github.com/manual/gh_issue_unlock` — Unlock conversation on an issue.
- `https://cli.github.com/manual/gh_issue_unpin` — Unpin an issue from the repository.
- `https://cli.github.com/manual/gh_issue_view` — View an issue in browser or terminal.

## Authentication

- `https://cli.github.com/manual/gh_auth` — Auth root: authenticating gh with GitHub.
- `https://cli.github.com/manual/gh_auth_login` — Interactive authentication with GitHub.
- `https://cli.github.com/manual/gh_auth_logout` — Remove authentication for a host.
- `https://cli.github.com/manual/gh_auth_refresh` — Refresh stored authentication credentials.
- `https://cli.github.com/manual/gh_auth_setup-git` — Configure git to use gh as credential helper.
- `https://cli.github.com/manual/gh_auth_status` — View current authentication status.
- `https://cli.github.com/manual/gh_auth_switch` — Switch the active authenticated account.
- `https://cli.github.com/manual/gh_auth_token` — Print the current auth token.

## Repository Management

- `https://cli.github.com/manual/gh_repo` — Repo root: create, clone, fork, and manage repositories.
- `https://cli.github.com/manual/gh_repo_archive` — Archive a repository.
- `https://cli.github.com/manual/gh_repo_autolink` — Autolink reference management.
- `https://cli.github.com/manual/gh_repo_autolink_create` — Create an autolink reference.
- `https://cli.github.com/manual/gh_repo_autolink_delete` — Delete an autolink reference.
- `https://cli.github.com/manual/gh_repo_autolink_list` — List autolink references.
- `https://cli.github.com/manual/gh_repo_autolink_view` — View an autolink reference.
- `https://cli.github.com/manual/gh_repo_clone` — Clone a repository locally.
- `https://cli.github.com/manual/gh_repo_create` — Create a new repository.
- `https://cli.github.com/manual/gh_repo_delete` — Delete a repository.
- `https://cli.github.com/manual/gh_repo_deploy-key` — Deploy key management.
- `https://cli.github.com/manual/gh_repo_deploy-key_add` — Add a deploy key.
- `https://cli.github.com/manual/gh_repo_deploy-key_delete` — Delete a deploy key.
- `https://cli.github.com/manual/gh_repo_deploy-key_list` — List deploy keys.
- `https://cli.github.com/manual/gh_repo_edit` — Edit repository settings.
- `https://cli.github.com/manual/gh_repo_fork` — Fork a repository.
- `https://cli.github.com/manual/gh_repo_gitignore` — Gitignore template management.
- `https://cli.github.com/manual/gh_repo_gitignore_list` — List available gitignore templates.
- `https://cli.github.com/manual/gh_repo_gitignore_view` — View a gitignore template.
- `https://cli.github.com/manual/gh_repo_license` — License template management.
- `https://cli.github.com/manual/gh_repo_license_list` — List available license templates.
- `https://cli.github.com/manual/gh_repo_license_view` — View a license template.
- `https://cli.github.com/manual/gh_repo_list` — List owned repositories.
- `https://cli.github.com/manual/gh_repo_rename` — Rename a repository.
- `https://cli.github.com/manual/gh_repo_set-default` — Set a default repository.
- `https://cli.github.com/manual/gh_repo_sync` — Sync a fork with its parent.
- `https://cli.github.com/manual/gh_repo_unarchive` — Unarchive a repository.
- `https://cli.github.com/manual/gh_repo_view` — View a repository in browser or terminal.

## API & Search

- `https://cli.github.com/manual/gh_api` — Make authenticated GitHub API requests (REST and GraphQL).
- `https://cli.github.com/manual/gh_search` — Search root: search GitHub from the CLI.
- `https://cli.github.com/manual/gh_search_code` — Search within code.
- `https://cli.github.com/manual/gh_search_commits` — Search commits.
- `https://cli.github.com/manual/gh_search_issues` — Search issues.
- `https://cli.github.com/manual/gh_search_prs` — Search pull requests.
- `https://cli.github.com/manual/gh_search_repos` — Search repositories.

## Configuration & Help

- `https://cli.github.com/manual/gh_config` — Config root: manage gh configuration.
- `https://cli.github.com/manual/gh_config_clear-cache` — Clear the CLI cache.
- `https://cli.github.com/manual/gh_config_get` — Print a specific config setting.
- `https://cli.github.com/manual/gh_config_list` — Print all config settings.
- `https://cli.github.com/manual/gh_config_set` — Update a config setting.
- `https://cli.github.com/manual/gh_help_environment` — Environment variables recognized by gh.
- `https://cli.github.com/manual/gh_help_exit-codes` — Exit codes and their meanings.
- `https://cli.github.com/manual/gh_help_formatting` — Output formatting options (JSON, Go template).
- `https://cli.github.com/manual/gh_help_mintty` — Mintty terminal compatibility notes.
- `https://cli.github.com/manual/gh_help_reference` — Comprehensive reference of all topics.
- `https://cli.github.com/manual/gh_help_telemetry` — Telemetry and data collection.

## Aliases & Extensions

- `https://cli.github.com/manual/gh_alias` — Alias root: define shortcuts for gh commands.
- `https://cli.github.com/manual/gh_alias_delete` — Delete an alias.
- `https://cli.github.com/manual/gh_alias_import` — Import aliases from a file.
- `https://cli.github.com/manual/gh_alias_list` — List defined aliases.
- `https://cli.github.com/manual/gh_alias_set` — Create or update an alias.
- `https://cli.github.com/manual/gh_completion` — Generate shell completion scripts.
- `https://cli.github.com/manual/gh_extension` — Extension root: manage gh extensions.
- `https://cli.github.com/manual/gh_extension_browse` — Browse extensions in the browser.
- `https://cli.github.com/manual/gh_extension_create` — Create a new extension.
- `https://cli.github.com/manual/gh_extension_exec` — Execute an installed extension by name.
- `https://cli.github.com/manual/gh_extension_install` — Install an extension from a repository.
- `https://cli.github.com/manual/gh_extension_list` — List installed extensions.
- `https://cli.github.com/manual/gh_extension_remove` — Remove an installed extension.
- `https://cli.github.com/manual/gh_extension_search` — Search for extensions.
- `https://cli.github.com/manual/gh_extension_upgrade` — Upgrade installed extensions.

## Status & Browsing

- `https://cli.github.com/manual/gh_status` — Print information about relevant work on GitHub.
- `https://cli.github.com/manual/gh_browse` — Open the repository in the browser.

## Releases

- `https://cli.github.com/manual/gh_release` — Release root: manage GitHub Releases.
- `https://cli.github.com/manual/gh_release_create` — Create a new release.
- `https://cli.github.com/manual/gh_release_delete` — Delete a release.
- `https://cli.github.com/manual/gh_release_delete-asset` — Delete a release asset.
- `https://cli.github.com/manual/gh_release_download` — Download release assets.
- `https://cli.github.com/manual/gh_release_edit` — Edit a release.
- `https://cli.github.com/manual/gh_release_list` — List releases.
- `https://cli.github.com/manual/gh_release_upload` — Upload assets to a release.
- `https://cli.github.com/manual/gh_release_verify` — Verify release artifact integrity.
- `https://cli.github.com/manual/gh_release_verify-asset` — Verify a release asset.
- `https://cli.github.com/manual/gh_release_view` — View information about a release.

## Labels

- `https://cli.github.com/manual/gh_label` — Label root: manage issue/PR labels.
- `https://cli.github.com/manual/gh_label_clone` — Clone labels from one repository to another.
- `https://cli.github.com/manual/gh_label_create` — Create a new label.
- `https://cli.github.com/manual/gh_label_delete` — Delete a label.
- `https://cli.github.com/manual/gh_label_edit` — Edit a label.
- `https://cli.github.com/manual/gh_label_list` — List labels in a repository.

## GitHub Actions — Runs

- `https://cli.github.com/manual/gh_run` — Run root: view and manage workflow runs.
- `https://cli.github.com/manual/gh_run_cancel` — Cancel a workflow run.
- `https://cli.github.com/manual/gh_run_delete` — Delete a workflow run.
- `https://cli.github.com/manual/gh_run_download` — Download artifacts from a run.
- `https://cli.github.com/manual/gh_run_list` — List recent workflow runs.
- `https://cli.github.com/manual/gh_run_rerun` — Rerun a failed workflow run.
- `https://cli.github.com/manual/gh_run_view` — View a summary of a workflow run.
- `https://cli.github.com/manual/gh_run_watch` — Watch a workflow run while it's in progress.

## GitHub Actions — Workflows

- `https://cli.github.com/manual/gh_workflow` — Workflow root: view and manage workflows.
- `https://cli.github.com/manual/gh_workflow_disable` — Disable a workflow.
- `https://cli.github.com/manual/gh_workflow_enable` — Enable a workflow.
- `https://cli.github.com/manual/gh_workflow_list` — List workflows.
- `https://cli.github.com/manual/gh_workflow_run` — Create a workflow_dispatch event.
- `https://cli.github.com/manual/gh_workflow_view` — View the summary of a workflow.

## GitHub Actions — Cache

- `https://cli.github.com/manual/gh_cache` — Cache root: manage Actions caches.
- `https://cli.github.com/manual/gh_cache_delete` — Delete a cache entry.
- `https://cli.github.com/manual/gh_cache_list` — List cache entries.

## Secrets & Variables

- `https://cli.github.com/manual/gh_secret` — Secret root: manage repository/organization secrets.
- `https://cli.github.com/manual/gh_secret_delete` — Delete a secret.
- `https://cli.github.com/manual/gh_secret_list` — List secrets.
- `https://cli.github.com/manual/gh_secret_set` — Set or update a secret.
- `https://cli.github.com/manual/gh_variable` — Variable root: manage repository/organization variables.
- `https://cli.github.com/manual/gh_variable_delete` — Delete a variable.
- `https://cli.github.com/manual/gh_variable_get` — Get a variable value.
- `https://cli.github.com/manual/gh_variable_list` — List variables.
- `https://cli.github.com/manual/gh_variable_set` — Set or update a variable.

## SSH & GPG Keys

- `https://cli.github.com/manual/gh_ssh-key` — SSH key root: manage SSH keys for your account.
- `https://cli.github.com/manual/gh_ssh-key_add` — Add an SSH key.
- `https://cli.github.com/manual/gh_ssh-key_delete` — Delete an SSH key.
- `https://cli.github.com/manual/gh_ssh-key_list` — List SSH keys.
- `https://cli.github.com/manual/gh_gpg-key` — GPG key root: manage GPG keys for your account.
- `https://cli.github.com/manual/gh_gpg-key_add` — Add a GPG key.
- `https://cli.github.com/manual/gh_gpg-key_delete` — Delete a GPG key.
- `https://cli.github.com/manual/gh_gpg-key_list` — List GPG keys.

## Gists

- `https://cli.github.com/manual/gh_gist` — Gist root: manage GitHub Gists.
- `https://cli.github.com/manual/gh_gist_clone` — Clone a gist locally.
- `https://cli.github.com/manual/gh_gist_create` — Create a new gist.
- `https://cli.github.com/manual/gh_gist_delete` — Delete a gist.
- `https://cli.github.com/manual/gh_gist_edit` — Edit a gist.
- `https://cli.github.com/manual/gh_gist_list` — List your gists.
- `https://cli.github.com/manual/gh_gist_rename` — Rename a gist file.
- `https://cli.github.com/manual/gh_gist_view` — View a gist in browser or terminal.

## Projects

- `https://cli.github.com/manual/gh_project` — Project root: manage GitHub Projects (beta).
- `https://cli.github.com/manual/gh_project_close` — Close a project.
- `https://cli.github.com/manual/gh_project_copy` — Copy a project.
- `https://cli.github.com/manual/gh_project_create` — Create a project.
- `https://cli.github.com/manual/gh_project_delete` — Delete a project.
- `https://cli.github.com/manual/gh_project_edit` — Edit a project.
- `https://cli.github.com/manual/gh_project_field-create` — Create a field in a project.
- `https://cli.github.com/manual/gh_project_field-delete` — Delete a field from a project.
- `https://cli.github.com/manual/gh_project_field-list` — List fields in a project.
- `https://cli.github.com/manual/gh_project_item-add` — Add an item to a project.
- `https://cli.github.com/manual/gh_project_item-archive` — Archive an item in a project.
- `https://cli.github.com/manual/gh_project_item-create` — Create a draft item in a project.
- `https://cli.github.com/manual/gh_project_item-delete` — Delete an item from a project.
- `https://cli.github.com/manual/gh_project_item-edit` — Edit an item in a project.
- `https://cli.github.com/manual/gh_project_item-list` — List items in a project.
- `https://cli.github.com/manual/gh_project_link` — Link a repository to a project.
- `https://cli.github.com/manual/gh_project_list` — List projects.
- `https://cli.github.com/manual/gh_project_mark-template` — Mark a project as a template.
- `https://cli.github.com/manual/gh_project_unlink` — Unlink a repository from a project.
- `https://cli.github.com/manual/gh_project_view` — View a project.

## Codespaces

- `https://cli.github.com/manual/gh_codespace` — Codespace root: manage GitHub Codespaces.
- `https://cli.github.com/manual/gh_codespace_code` — Open a codespace in VS Code.
- `https://cli.github.com/manual/gh_codespace_cp` — Copy files to/from a codespace.
- `https://cli.github.com/manual/gh_codespace_create` — Create a codespace.
- `https://cli.github.com/manual/gh_codespace_delete` — Delete a codespace.
- `https://cli.github.com/manual/gh_codespace_edit` — Edit a codespace.
- `https://cli.github.com/manual/gh_codespace_jupyter` — Open a codespace in JupyterLab.
- `https://cli.github.com/manual/gh_codespace_list` — List codespaces.
- `https://cli.github.com/manual/gh_codespace_logs` — Access codespace logs.
- `https://cli.github.com/manual/gh_codespace_ports` — Manage forwarded ports in a codespace.
- `https://cli.github.com/manual/gh_codespace_ports_forward` — Forward a port.
- `https://cli.github.com/manual/gh_codespace_ports_visibility` — Change port visibility.
- `https://cli.github.com/manual/gh_codespace_rebuild` — Rebuild a codespace.
- `https://cli.github.com/manual/gh_codespace_ssh` — SSH into a codespace.
- `https://cli.github.com/manual/gh_codespace_stop` — Stop a codespace.
- `https://cli.github.com/manual/gh_codespace_view` — View a codespace.

## Other Commands

- `https://cli.github.com/manual/gh_org` — Org root: manage GitHub organizations.
- `https://cli.github.com/manual/gh_org_list` — List organizations for a user.
- `https://cli.github.com/manual/gh_licenses` — List available open source licenses.
- `https://cli.github.com/manual/gh_ruleset` — Ruleset root: manage repository rulesets.
- `https://cli.github.com/manual/gh_ruleset_check` — Check ruleset compliance for a branch.
- `https://cli.github.com/manual/gh_ruleset_list` — List rulesets.
- `https://cli.github.com/manual/gh_ruleset_view` — View a ruleset.
- `https://cli.github.com/manual/gh_attestation` — Attestation root: manage artifact attestations.
- `https://cli.github.com/manual/gh_attestation_download` — Download attestation bundles.
- `https://cli.github.com/manual/gh_attestation_trusted-root` — Output trusted root for verification.
- `https://cli.github.com/manual/gh_attestation_verify` — Verify attestation integrity.
- `https://cli.github.com/manual/gh_copilot` — Copilot root: extensions and access to GitHub Copilot.
- `https://cli.github.com/manual/gh_skill` — Skill root: manage Claude Code skills via gh CLI.
- `https://cli.github.com/manual/gh_skill_install` — Install a skill from a repository.
- `https://cli.github.com/manual/gh_skill_preview` — Preview a skill locally.
- `https://cli.github.com/manual/gh_skill_publish` — Publish a skill to GitHub.
- `https://cli.github.com/manual/gh_skill_search` — Search for skills.
- `https://cli.github.com/manual/gh_skill_update` — Update an installed skill.
- `https://cli.github.com/manual/gh_agent-task` — Agent task root: manage agent tasks.
- `https://cli.github.com/manual/gh_agent-task_create` — Create an agent task.
- `https://cli.github.com/manual/gh_agent-task_list` — List agent tasks.
- `https://cli.github.com/manual/gh_agent-task_view` — View an agent task.
- `https://cli.github.com/manual/gh_preview` — Preview root: preview upcoming features.
- `https://cli.github.com/manual/gh_preview_prompter` — Preview the interactive prompter feature.
