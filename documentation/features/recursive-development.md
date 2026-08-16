# Recursive development validation

Internal reference for the Dev-only workflow that gives an agent evidence from a real, isolated Agent Session Manager window. It does not replace human review.

## Safety model

The only launch interface is `--recursive-development-run-id <UUID>`. The app validates a canonical UUID and derives its support directory beneath `~/Library/Application Support/agent-session-manager-recursive-runs/`; it never accepts a caller-supplied persistence path. A production binary receiving the flag terminates before its application state is initialized. Normal Dev launches retain `agent-session-manager.dev` unchanged.

One coordinator holds a lock in the Git common directory while it builds the shared `AgentSessionManagerDev.app`. It refuses to start when any ordinary Dev process is running. It launches the exact bundle directly, verifies the run manifest's source commit, bundle URL, PID, and title, and sends `SIGTERM` only to that verified PID. It never uses `pkill`, restart targets, or resets ordinary Dev/production state. A failed run stays available for diagnosis.

## Commands and artifacts

`scripts/recursive-development.sh` provides `start`, `status`, `collect`, `profile`, and `stop`; all except `start` require `--run-id`. A run creates `.build/recursive-development/<UUID>/run.json`, screenshot, telemetry, performance, and report directories. `run.json` contains only source identity, paths, timestamps, PID, and state—never environment values, terminal output, credentials, or Agent Control material.

The app atomically writes `recursive-development-runtime.json` inside the isolated support directory with `starting`, `ready`, and `stopped` transitions. Its window title is `Agent Session Manager (Dev · <UUID-prefix>)`. The coordinator samples CPU/RSS once each second after readiness and summarizes observations without a pass/fail threshold. `profile` is optional and first verifies that the local Time Profiler template exists.

## Validation procedure

Install the one-time prerequisite with `codex plugin add computer-use@openai-bundled`, start a new Codex session, and grant Screen Recording and Accessibility to Codex Computer Use. Before every interaction inspect current Computer Use state, prefer accessibility elements to coordinates, and do not retain full accessibility trees because terminal content may be present. Save returned screenshot URLs under the run's `screenshots/` directory and avoid secrets in the visible window.

Start a run, verify its commit and exact title, then create a tab through the real UI. Enable Debug Mode through the actual Settings UI when durable traces are needed. Use the real New Pane flow when a harness is relevant; V1 does not type terminal prompts. Collect bounded telemetry and focused Dev XCTest evidence, then stop only the owned run. If Computer Use setup, permissions, or calibration is unavailable, mark visual validation unverified while retaining ordinary XCTest evidence separately.

Calibration succeeds only after an isolated launch/title, a real tab, saved screenshot, one post-Debug-Mode trace, and clean closure of the owned run. Manual acceptance requires that sequence twice consecutively, with no relevant malformed JSONL/invariants and the parent production app still running.

## Choosing validation tools

Use the tools together, not as interchangeable proof. Each produces a
different kind of evidence.

| Tool | Use it for | Do not treat it as |
| --- | --- | --- |
| Swift unit tests | Fast deterministic logic, persistence, path-safety, and coordinator behavior | Proof that a visible macOS interaction renders correctly |
| Dev XCTest | Repeatable UI assertions and broad regression coverage, especially on CI or a dedicated Mac | Visual acceptance when automation cannot initialize or when the test fabricates state |
| Computer Use | One or a few high-value real-window flows, safe screenshots, and visual acceptance of an isolated owned run | A headless or background test runner, a terminal-input API, or proof of internal state without visual evidence |
| Telemetry and invariants | Bounded corroboration of runtime behavior after Debug Mode is enabled | A substitute for a screenshot or real visible interaction |
| Instruments | Targeted diagnosis of startup, rendering, concurrency, or terminal behavior | A mandatory pass/fail benchmark in V1 |

Computer Use is usually less disruptive to the desktop than local XCTest
because it operates the owned app through Accessibility rather than starting
an Xcode UI test session. It can still foreground the target window while it
clicks or types, so it is not guaranteed background automation. Keep a run
serialized, avoid operating it while a user is performing sensitive work, and
use XCTest/CI for large deterministic suites.

### Reusable sample flow

The agent skill includes a `tab-and-pane-calibration` sample flow. It starts a
fresh owned run, verifies identity, creates a tab through the visible UI,
saves a safe screenshot, enables Debug Mode, optionally attaches an existing
disposable worktree through New Pane, collects selected-pane evidence, runs
focused XCTest separately, and closes only the owned run.

The sample deliberately attaches a caller-supplied disposable checkout rather
than creating and deleting worktrees as test debris. Copy it for a new visual
journey, rename the expected UI outcome, and keep its ownership and evidence
rules unchanged.

## Deferred scope

Cross-process Agent Control proxying, terminal-input APIs, parallel Dev instances, reusable scenario libraries beyond the sample flow, and performance thresholds are intentionally deferred.
