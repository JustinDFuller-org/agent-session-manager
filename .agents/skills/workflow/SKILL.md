---
name: workflow
description: "Development workflow for this repo: plan → test → implement → human review → repeat. Load when starting any feature, bug fix, or refactor."
---

## Workflow

**1. Plan** — Always present a plan before writing code, whether or not plan mode is active. Explore the codebase first. Reference specific files and functions. End with a clear list of changes.

**1.5 Configuration** — For any feature with user-facing behavior that could vary by project or preference, design a configurable setting. Add the property to `AppSettings`, persist it via `SettingsPersistence` (save + restore pair, new JSON file), expose it in a `SettingsView` tab with an appropriate control and accessibility identifier, and call restore from `App.swift`.

**1.7 Documentation** — Create or update `documentation/features/<feature>.md` describing what the feature does, how to use it, and how to configure it. Create the `documentation/features/` directory if it doesn't exist.

**2. Test** — Write tests before or alongside implementation. This repo has two test layers:
- **Unit tests** (`Tests/`) — fast, `swift test`, for logic and model behavior
- **UI tests** (`UITests/`) — full app, `make test-ui`, for user-visible behavior

Every new behavior needs **both** a unit test and a UI test. Every changed behavior needs its tests updated.

**3. Implement** — Write the minimal code to make the tests pass. Refactor code and tests together as implementation reveals better structure. Build must be clean: `swift build`.

**4. Verify** — REQUIRED before pausing for human review. Run all CI checks:

```bash
swift test                                                        # unit tests — must pass
swift-format lint --recursive --strict Sources/ Tests/ UITests/  # format — must pass
swiftlint lint --strict --config .swiftlint.yml                   # lint — must pass
make xcodeproj && make test-ui-dev                                # UI tests — must pass (dev build, isolated from prod settings)
```

UI test regressions are easy to miss and costly to fix later. **Never skip this step.** The git pre-commit hook runs unit tests, format, and lint; the pre-push hook runs UI smoke tests (`AppLaunchTests`, `NewTabTests`, `NewPaneTests`), so most regressions will be caught before they reach a PR. Run `make setup-hooks` once to install them.

Use `make test-ui-dev` (not `make test-ui`) so tests run against the dev build and write to `agent-session-manager.dev` instead of the production app support directory. If a test run is interrupted before tearDown completes, the settings will be left dirty — run `make reset-app-state-dev` to clean them up (`make reset-app-state` for the prod directory).

**5. Commit & PR** — After all CI checks pass, automatically:

1. Stage and commit all changes with a message that includes the issue number and explains *why* the change was made.
2. Push the branch.
3. Open a PR with `gh pr create` using this exact template (fill in the bracketed placeholders):

```
gh pr create --title "[conventional-type]: [issue title] (#[N])" --body "$(cat <<'EOF'
> [!NOTE]
> This PR title, description, and code were generated with Claude Code.

## Summary

- [bullet points describing what changed and why]

## Test plan

- [x] [each CI command that was run and passed, e.g. `swift test`, `make lint`, `make test-ui`]
- [ ] [any manual verification steps left for the human reviewer]

Closes #[N]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

The PR title must use a conventional commit prefix (`feat:`, `fix:`, `refactor:`, etc.) and include the GitHub issue title so reviewers immediately see what is being addressed.

**6. Pause** — After the PR is open, stop and tell the human what to manually verify. Link to the open PR. Don't claim success until a human has exercised the feature.

**7. Repeat** — Incorporate feedback and return to step 1 for the next change.

## Test commands

```bash
swift build                                                       # must pass before any commit
swift test                                                        # unit tests (no Xcode needed)
make lint                                                         # swift-format check (matches CI)
swiftlint lint --strict --config .swiftlint.yml                   # swiftlint check (matches CI)
make xcodeproj                                                    # regenerate after project.yml changes
make test-ui-dev                                                  # UI tests against dev build (isolated from prod settings)
make reset-app-state-dev                                          # clear dev settings if a test run was interrupted mid-tearDown
make reset-app-state                                              # same for prod settings
```

## UI test maintenance

`UITestAppSupport.directory` (`UITests/Helpers/UITestAppSupport.swift`) is the single source of truth for which app support directory UITests read and write. It returns `agent-session-manager.dev` when compiled with `DEV_BUILD` (`-configuration Dev`), and `agent-session-manager` otherwise.

When a new settings file is added to the app, update it in **two places**:
1. `UITests/Helpers/BaseTestCase.swift` — `clearPersistedState()` file list
2. `Makefile` — both the `reset-app-state` and `reset-app-state-dev` file lists
