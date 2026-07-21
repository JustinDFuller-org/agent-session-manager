# User-Facing Documentation Plan

Status: planning baseline

This document plans the migration from implementation-oriented project documentation to a user guide for the deployed GitHub Pages site. It is an internal planning document and is excluded from the Jekyll build.

## 1. Current State

### Repository and site structure

The branch already contains a GitHub Pages/Jekyll site shell:

- [`_config.yml`](_config.yml) defines the site metadata, custom domain, Markdown processing, and feature-document layout.
- [`_data/navigation.yml`](_data/navigation.yml) defines the sidebar and homepage documentation catalog.
- [`index.md`](index.md), [`documentation/index.md`](documentation/index.md), and the `_layouts/` directory provide the homepage and documentation shell.
- [`CNAME`](CNAME) points the site at `agent-session-manager.justindfuller.com`.
- There is no Pages deployment workflow in `.github/workflows/`; deployment settings are configured outside the repository and must be verified separately.

The deployed site currently has a usable visual shell and landing page, but its documentation catalog still treats all documentation as one audience. The catalog includes user workflows alongside Debug Mode, tracing, invariants, development builds, UI test screenshots, distribution, and developer maps.

### Content inventory

There are 33 documents under [`documentation/features/`](documentation/features/). They describe real product behavior, but they were generally written as feature or implementation guides rather than as user help.

The current content has several problems:

- Pages often begin with internal concepts instead of explaining what the feature is useful for.
- Terms such as harness, worktree, provider, status line, JSONL, invariant, and trace are not consistently translated for people who cannot see the code.
- Some pages mix exact user steps with source paths, class names, persistence schemas, test instructions, or developer maps.
- The homepage and README do not fully match the current implementation. For example, the current harness surface includes Claude Code, Cursor, Codex, and OpenCode, while older public copy names only three tools.
- The navigation does not expose every current feature document, including the OpenCode guide.
- The site has one durable hero image, but user guides do not yet have a maintained screenshot set.

### Existing evidence and source boundaries

The repository already provides useful evidence for a future user guide:

- [`AGENTS.md`](AGENTS.md) defines the product mental model, supported workflows, terminology constraints, and public-copy rules.
- [`Sources/AgentSessionManager/Views/`](Sources/AgentSessionManager/Views/) contains the user-visible labels and settings structure.
- [`documentation/features/setup-wizard.md`](documentation/features/setup-wizard.md), [`panes.md`](documentation/features/panes.md), [`profiles.md`](documentation/features/profiles.md), [`status-line.md`](documentation/features/status-line.md), and [`notifications.md`](documentation/features/notifications.md) are the main user-workflow sources.
- [`documentation/features/agent-harness-feature-matrix.md`](documentation/features/agent-harness-feature-matrix.md) records the current cross-harness capability surface.
- [`UITests/ScreenshotTests.swift`](UITests/ScreenshotTests.swift) captures real application flows, including onboarding, tabs, panes, settings, focus mode, notifications, and diagnostic dashboards.
- [`documentation/features/screenshots.md`](documentation/features/screenshots.md) defines the screenshot authenticity and generation workflow.

Public claims must be checked against source code, current UI labels, tests, and feature documentation before publication. README text, stale screenshots, and historical progress notes are not sufficient sources by themselves.

## 2. Information Developers and Agents Need

Developers and coding agents need information that helps them change the product safely, understand why it is shaped this way, and diagnose failures without rediscovering repository rules.

| Information type | Questions it answers | Best source and delivery time |
| --- | --- | --- |
| Operating constraints | What must an agent preserve? What actions are unsafe? | `AGENTS.md` at task start; relevant skills on demand |
| Domain model | What are tabs, panes, worktrees, profiles, harnesses, and status data? | Internal dictionary and architecture notes before implementation |
| Behavior contracts | What must remain true across launches, harnesses, settings, and cleanup? | Feature docs, invariants, source, and focused tests during implementation |
| Integration boundaries | Which behavior belongs to the app, Git, a harness, GitHub, Sparkle, or macOS? | Feature matrix and source maps when changing integrations |
| Failure and diagnosis paths | Where do errors, traces, invariants, notifications, and persisted state appear? | Internal runbooks and `agent-data-access` during diagnosis |
| Build and test safety | Which commands are safe, isolated, and authoritative? | `AGENTS.md`, workflow skill, Makefile, and test helpers before verification |
| Release and deployment operations | How are builds signed, distributed, updated, and published? | Internal distribution and release runbooks when preparing a release |
| Historical rationale | Why does a behavior or compatibility rule exist? | Focused feature history, issue references, and commit context during review |

Agent-facing documentation should optimize for discoverability from the task context. It should name the canonical file, command, test, invariant, or skill rather than repeat every implementation detail in a general guide.

Developer-facing documentation should optimize for maintaining contracts. It should explain ownership, data flow, compatibility behavior, failure modes, and verification evidence, even when those details would be confusing or irrelevant to a regular user.

## 3. Information Users Need

Regular users need to understand the product, decide whether it helps them, complete common tasks, and recover when something does not work. They should not need access to the repository or knowledge of the implementation.

| Information type | User question | Preferred format and timing |
| --- | --- | --- |
| Product explanation | What is Agent Session Manager? | Short homepage statement, one product screenshot, and a concrete use case |
| Value and fit | Why would I use this, and when is it useful? | Overview page framed around running several agent sessions in parallel |
| Requirements and installation | What do I need before I start? How do I install or update it? | Short prerequisites and download/update guide before the quickstart |
| Mental model | What is a tab, pane, agent tool, session, or separate working copy? | Plain-language concepts page with a labeled application screenshot |
| First successful task | How do I open a project and start an agent? | Sequential quickstart using the real first-launch wizard, New Tab, and New Pane flows |
| Everyday workflows | How do I work on multiple tasks, focus one task, reopen work, or use a shell? | Task-oriented guides with exact menu names, buttons, shortcuts, and screenshots |
| Tool selection | Which supported agent tool can I use, and how do I enable it? | Harness overview with one short page per supported tool and clear prerequisites |
| Configuration | How do I customize flags, profiles, status information, and notifications? | Settings guides organized around decisions users make, not model or persistence types |
| Project isolation | What happens to my branch and files when I create a pane? | Plain-language worktree explanation, with advanced Git terminology introduced only when needed |
| Feedback and attention | How do I know an agent is working, waiting, or finished? | Visual guide for activity indicators, status information, notifications, and GitHub updates |
| Recovery | What should I do if a tool is missing, a pane will not start, permissions appear, or a checkout conflicts? | Troubleshooting pages organized by symptom and next action |
| Reference | What are the shortcuts and exact settings locations? | Compact searchable reference page, linked from task guides |

User-facing language should use the exact labels visible in the app while explaining any product-specific term at first use. For example, describe a pane as “one terminal session inside a tab” before using the word pane on its own.

## 4. Documentation Strategy

### Separate the audiences

The deployed site should become user-only. Future public documentation should live under `documentation/user-guide/`, while `documentation/features/`, `documentation/dictionary.md`, `AGENTS.md`, skills, and release or test runbooks remain repository-only.

The Jekyll configuration should exclude internal documentation paths and the planning artifacts. The public navigation should contain only user guides. Internal documentation can still link to user guides when that helps maintainers verify the public explanation.

### Use a task-first information architecture

The public site should lead users through these paths:

1. Overview: what the app is and who benefits from it.
2. Install and first launch: requirements, download, setup wizard, and first pane.
3. Core concepts: tabs, panes, agent tools, sessions, and separate working copies.
4. Daily work: multiple panes, focus mode, shell access, persistence, and shortcuts.
5. Configure: tools, flags, profiles, status information, notifications, and cleanup choices.
6. Integrations: supported agent tools and optional GitHub pull-request features.
7. Troubleshoot: symptom-led recovery and when to collect diagnostic information.
8. Reference: shortcuts, settings locations, supported tools, and terminology.

The homepage should answer “what is this?” and “how do I start?” without requiring a reader to open an internal feature page. The documentation index should support both a guided quickstart and direct task search.

### Use a consistent page contract

Every user guide should contain, when applicable:

1. **What it is** — one plain-language definition.
2. **Why you might use it** — the user problem or decision it addresses.
3. **Before you start** — prerequisites, permissions, or settings.
4. **How to use it** — numbered steps using exact UI labels.
5. **What you should see** — the expected result or state change.
6. **If it does not work** — symptom-led recovery steps.
7. **Related tasks** — links to the next likely action.

Implementation details belong in internal documentation or a clearly labeled maintainer reference, not in the user guide.

### Make screenshots durable and trustworthy

Screenshots should be committed under `assets/img/docs/` and referenced from the user guides with descriptive captions and alt text. They should be selected from real flows in `ScreenshotTests.swift`, generated with the approved Dev configuration, and refreshed when the corresponding UI changes.

Initial screenshot priorities are:

- first-launch setup wizard
- empty state and New Tab
- New Pane with a selected agent tool
- one pane and multiple panes
- settings for tools, profiles, status information, and notifications
- focused pane and activity indicators
- notification sidebar and update indicator when the feature is user-visible

Diagnostic dashboards, invariant views, and test-specific screenshots should remain internal unless a future user troubleshooting guide proves they are useful to regular users.

### Deliver information at the right time

- A new visitor gets the concise overview, product screenshot, requirements, and download link.
- A new user gets a sequential quickstart immediately after installation.
- An active user gets task guides through navigation, search, and links from related pages.
- A blocked user gets symptom-led troubleshooting without needing to understand the implementation.
- A developer or agent gets repository instructions and relevant internal skills at task start, with deeper references loaded only for the feature being changed.
- A maintainer gets release, deployment, and screenshot verification runbooks during review and release work.

### Maintain a documentation quality gate

For every user-visible feature change, review whether the change requires:

- a new or updated user guide
- a screenshot or screenshot caption update
- a change to the quickstart, terminology, or navigation
- a troubleshooting entry
- a corresponding internal feature or agent reference

Reviewers should verify the copy against the current UI and source, confirm that links resolve, and reject unexplained implementation terminology or claims that cannot be verified.

## 5. Migration TODO

- [x] Inventory every current feature document and classify it as user-facing, internal-only, or requiring two versions.
- [ ] Create `documentation/user-guide/` and establish the user-guide page template.
- [ ] Update Jekyll exclusions so internal documentation and planning artifacts cannot be published.
- [ ] Replace the current mixed-audience navigation with user-guide navigation.
- [ ] Rewrite the homepage and documentation index around user goals.
- [ ] Write the overview, requirements, quickstart, and core-concepts pages first.
- [ ] Migrate tabs, panes, agent-tool selection, project isolation, persistence, and cleanup into task guides.
- [ ] Migrate profiles, tool options, status information, notifications, focus mode, and shortcuts into task guides.
- [ ] Add user-facing update, permissions, missing-tool, pane-startup, and checkout-conflict troubleshooting.
- [ ] Add and promote the first durable screenshot set from the real-flow UI tests.
- [ ] Remove internal source paths, schemas, class names, telemetry catalogs, and test commands from public pages.
- [ ] Add link checking and a documented local Jekyll build or equivalent rendered-site check.
- [ ] Verify the custom-domain deployment and representative user-guide URLs after each migration phase.
- [ ] Recheck README and homepage claims against the current four-tool implementation before publishing changes.

### Current feature inventory

Classification is based on the role of each document in the migration, not on whether the existing file is ready to publish:

- **User-facing source** — primarily explains a user task or decision and can supply a single public guide after plain-language editing.
- **Requires two versions** — describes a user-visible capability and also contains implementation, persistence, telemetry, diagnostic, or integration detail; retain the internal document and create a separate public guide.
- **Internal-only** — primarily documents development, release, testing, diagnostics, architecture, or historical implementation behavior; do not migrate the existing document to the public guide.

| Document | Classification | Evidence and migration action |
| --- | --- | --- |
| `agent-harness-feature-matrix.md` | Internal-only | Canonical code-observed integration audit; use it to verify a future user-facing harness overview, but keep the matrix internal. |
| `codex-cli.md` | Requires two versions | Combines pane setup and CLI options with status-line and persistence details; retain the integration reference and write a user tool guide. |
| `continue-on-restart.md` | Requires two versions | User-visible restart behavior is mixed with persistence files and implementation symbols; split the user setting guide from the internal contract. |
| `cursor-cli.md` | Requires two versions | Combines enabling and creating a pane with hooks, provider behavior, flags, and persistence; retain the technical reference and write a user tool guide. |
| `debug-logging.md` | Internal-only | Documents durable diagnostic files, unified logging, and Console or Instruments workflows; keep it as a maintainer diagnosis reference. |
| `default-branch.md` | Requires two versions | Explains user settings while also documenting data flow, telemetry, persistence, and implementation symbols; split public configuration help from the internal contract. |
| `dev-build.md` | Internal-only | Covers development builds, Xcode, commands, and UI test safety; keep it in repository documentation. |
| `distribution.md` | Internal-only | Describes signing, notarization, release tooling, and operator verification; use it for a future installation guide only as a source, not as a public page. |
| `focus-pane.md` | Requires two versions | User workflow and settings are mixed with persistence and telemetry behavior; split the public Focus Pane guide from the internal behavior reference. |
| `invariants.md` | Internal-only | Defines diagnostic contracts, JSONL output, catalogs, and incident collection; keep it internal. |
| `notifications.md` | Requires two versions | User-visible notification workflows are mixed with bundle identity, hooks, permission diagnosis, and trace details; split public notification help from the internal reference. |
| `observability-dashboard.md` | Internal-only | Documents the trace dashboard and OpenTelemetry data model for diagnosis; keep it internal unless a later troubleshooting need is established. |
| `opencode-cli.md` | Requires two versions | Combines user setup with server, session, security, downgrade, and invariant behavior; retain the technical reference and write a user tool guide. |
| `pane-loading-indicator.md` | Requires two versions | Describes visible loading and error states alongside implementation behavior; retain the internal contract and explain recovery in the public pane guide. |
| `panes.md` | Requires two versions | Provides the core user workflow but also mixes harness, worktree, persistence, permissions, and implementation-specific details; split the public pane guide from the internal reference. |
| `pr-merged-notifications.md` | User-facing source | Primarily explains what users see and which action to choose; migrate it into a task-oriented pull-request workflow guide. |
| `pr-tracking.md` | Requires two versions | Combines user-facing PR status and configuration with provider and implementation details; split the public PR guide from the internal integration reference. |
| `profile-ordering.md` | User-facing source | Explains a user decision and its effect on New Pane preselection; migrate it into the profiles configuration guide. |
| `profiles.md` | User-facing source | Primarily documents creating, editing, displaying, and applying profiles; migrate it into the public configuration guide. |
| `screenshots.md` | Internal-only | Defines real-flow UI test and PR screenshot generation; keep it as a maintainer workflow. |
| `session-names.md` | User-facing source | Primarily explains the visible session-name controls and their effect; migrate it into the core concepts or pane guide. |
| `settings-navigation.md` | Internal-only | Documents SwiftUI layout choices, accessibility identifiers, and window shell details; keep it as an implementation reference. |
| `setup-wizard.md` | Requires two versions | User onboarding is mixed with persistence files, classes, accessibility identifiers, and UI-test gating; split the public first-launch guide from the internal reference. |
| `status-line.md` | Requires two versions | User configuration is mixed with providers, catalogs, invariants, and payload behavior; split public status-information help from the internal contract. |
| `tab-loading-indicator.md` | Internal-only | Explicitly describes superseded historical behavior; retain only as migration history and direct readers to current activity indicators. |
| `tab-pane-activity-indicators.md` | Requires two versions | Explains a user-visible attention model while also documenting accessibility and tracing details; split the public visual guide from the internal behavior reference. |
| `tab-pane-reordering.md` | User-facing source | Primarily documents the user gesture, scope, and result; migrate it into the daily-work guide. |
| `terminal-rendering.md` | Internal-only | Documents a SwiftTerm fork, rendering internals, and maintainer verification; keep it internal. |
| `terminal-scrollback.md` | User-facing source | Primarily explains scrollback behavior and its setting; migrate it into the daily-work or reference guide. |
| `tracing.md` | Internal-only | Defines OpenTelemetry file layout, span catalogs, retention, and diagnosis; keep it internal. |
| `update-reminder.md` | Requires two versions | Combines the visible update flow with distribution-channel routing and release implementation; split public update help from the internal release reference. |
| `worktree-cleanup.md` | Requires two versions | Explains user cleanup choices while also documenting Git commands, persistence, and managed-worktree rules; split public recovery help from the internal contract. |
| `worktree-creation.md` | Requires two versions | Combines the New Pane workflow with resolution order, Git operations, terminal purity, and developer maps; split the public project-isolation guide from the internal reference. |

The inventory records stale or historical material without correcting it in this step. In particular, the `panes.md`, `worktree-creation.md`, and `distribution.md` sources contain older three-tool wording that must be checked against the current Claude Code, Cursor, Codex, and OpenCode implementation before public migration.

## Scope of This Planning Step

This change establishes the audience model and migration backlog. It does not rewrite the existing feature guides, change application behavior, add screenshots, or alter public navigation beyond excluding this internal planning document from the Jekyll output.
