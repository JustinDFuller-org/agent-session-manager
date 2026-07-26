# Panes

A **pane** is a terminal session inside a tab. Each pane runs an AI agent CLI: Claude Code, Cursor, or Codex. All three harnesses use the shared worktree flow: the app can attach to existing git checkouts or create **managed** trees under `.agent-session-manager/worktrees/<name>` inside the tab’s repository. See [worktree-creation.md]({{ '/documentation/features/worktree-creation/' | relative_url }}).

## Creating a pane

Use **⌘P** (default; configurable under **Settings → Shortcuts → New Pane in Current Tab**) or **File → New Pane in Current Tab** to open the New Pane sheet.

### Fields

**CLI** — Pick the tool to launch. Only tools enabled in **Settings → Harnesses** appear.

**Session / name field** — One text field, shared across tools. Switching tools preserves whatever was typed. It accepts a session name, branch ref, or existing worktree name and routes every harness through the same app-owned Git resolution path.

**CLI options** — Flags enabled in **Settings → Harnesses** appear as toggles and fields. Options marked default-on in Settings start checked.

Choose **Open** or press Return to create the pane.

## Status line

Each pane shows a configurable status bar at the bottom (model, cost, context usage, worktree name, and more). Configure items in **Settings → Status Line**.

## Focus mode

When a tab contains multiple panes, double-click a pane header or right-click and choose **Focus This Pane** to give that terminal the full tab body while keeping the tab bar visible. See [focus-pane.md]({{ '/documentation/features/focus-pane/' | relative_url }}).

## Open Shell Here

Right-click a pane header and choose **Open Shell Here** to create a plain shell pane in the same working directory. The new shell pane is named from the source pane so you can tell where it came from, for example `shell:reader`, `shell:reader-2`, and so on.

## Session persistence

Open panes are saved to `~/Library/Application Support/agent-session-manager/sessions.json`. On relaunch, the app restores tabs and restarts the CLI in any pane whose checkout still exists on disk (see restore rules in [worktree-creation.md]({{ '/documentation/features/worktree-creation/' | relative_url }})).

## Attention notifications

When a tool sends a terminal bell (`\a`), Agent Session Manager can surface [in-app notifications and optional macOS banners]({{ '/documentation/features/notifications/' | relative_url }}) (including when that pane is focused).

## macOS Permission Prompts

When you open your first pane for a repository, macOS may show permission dialogs like:

- **"AgentSessionManager" would like to access files in your Documents folder.**
- **"AgentSessionManager" would like to access files in your Desktop folder.**
- **"AgentSessionManager" would like to access data from other apps.**

These are one-time Transparency, Consent, and Control (TCC) prompts. They occur because Claude Code scans common directories during startup (project detection, configuration discovery). Grant permission once and macOS remembers the decision — the prompts should not repeat.

### What we already mitigate

The app runs the user’s shell as `zsh -i -c '<command>'` (and omits the login `-l` flag). That avoids sourcing `/etc/zprofile` and `~/.zprofile`, which can trigger extra TCC prompts when those scripts touch protected paths. The shell is still interactive (`-i`), so `~/.zshrc` can run and tools like Homebrew or version managers can adjust `PATH`. The app does **not** use `zsh -f` (which skips init files entirely and often breaks CLI discovery).

### Environment sanitization

Before a pane process starts, the app sanitizes the environment it inherited:

- `TERM=xterm-256color` and `COLORTERM=truecolor` are added if unset (SwiftTerm's advertised terminal capabilities).
- `LANG=en_US.UTF-8` is added if unset.
- `PATH` is merged with the system default entries from `/etc/paths` and `/etc/paths.d/*` — the same files macOS uses for login shells — so tools like `go`, Homebrew, and version managers are findable even when the app was launched from Finder/DMG and inherited LaunchServices' minimal PATH.

Inherited values are always preserved. When Agent Session Manager is launched from a terminal, the parent shell usually supplies a complete `PATH` and `TERM`, so the sanitizer is a no-op. When launched from the DMG via Finder, the sanitizer restores the missing baseline.

For process launches and environment details when diagnosing issues, see [debug-logging.md]({{ '/documentation/features/debug-logging/' | relative_url }}).

### If prompts persist across sessions

macOS stores TCC decisions per app bundle. If permissions don't stick:

1. Open **System Settings → Privacy & Security**
2. Check **Files and Folders** and **Full Disk Access** for Agent Session Manager entries
3. Run `tccutil reset All com.justinfuller.agent-session-manager` to reset and re-grant

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘T (default) | New tab |
| ⌘P (default) | New pane in current tab |
| ⌘W | Close active pane |
| ⌘K | Close active tab |
| ⌘1–⌘9 | Switch to tab by index |

For fallback creation from the configured **default branch**, see [default-branch.md]({{ '/documentation/features/default-branch/' | relative_url }}).
