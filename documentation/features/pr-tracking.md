# GitHub PR Tracking

## What it does

GitHub PR Tracking detects the pull request associated with the current git branch and displays its number, title, and state in the status line at the bottom of each pane. The PR chip is clickable — clicking it opens the pull request in your default browser.

This works for all CLI tools (Claude Code, Codex, Cursor, OpenCode) because it runs independently of any tool's session data. It uses `gh pr view <branch>` to query the GitHub CLI.

## How to use

1. Ensure the [GitHub CLI](https://cli.github.com) (`gh`) is installed and authenticated (`gh auth login`).
2. Open **Settings** (⌘,) and go to the **Status Line** tab.
3. Enable the **Track pull requests** toggle in the **GitHub PR Tracking** section.
4. Add the **PR** item to a status line row (it appears in the "Add Item" menu as "PR").
5. When you create a pane on a branch that already has an open pull request, the PR chip appears in the status line:
   - **Green dot** — open
   - **Purple dot** — merged
   - **Red dot** — closed
6. Click the PR chip to open the pull request in your browser.

## How it works

When a pane starts, the app runs:

```
gh pr view <branch> --json number,title,state,url
```

in the pane's working directory. The current branch is determined by `git branch --show-current`. If `gh` returns a PR, the data is displayed in the status line. The query repeats every 60 seconds to catch status changes.

If no PR exists for the branch, or `gh` is not installed or not authenticated, nothing is shown.

## How to configure

| Setting | Location | Default | Description |
|---|---|---|---|
| GitHub PR Tracking | Settings → Status Line | On | Enable or disable PR detection |

The setting is persisted to `~/Library/Application Support/agent-session-manager/pr-tracking-settings.json`.
