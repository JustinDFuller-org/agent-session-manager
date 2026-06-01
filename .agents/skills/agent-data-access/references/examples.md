# Captured Telemetry Examples

These are exact read-only commands and projected outputs captured from local production and development telemetry on June 1, 2026. The projection keeps examples concise while preserving the retrieved raw fields.

## Current Production Pane

```bash
.agents/skills/agent-data-access/scripts/collect-telemetry.sh \
  --app prod \
  --tab "Agent Session Manager" \
  --pane "telemetry-skill" \
  --since 24h \
  --limit 3 |
jq '{currentSessionMatches,candidateTraceFiles,paneSpans,legacyFiles}'
```

```json
{
  "currentSessionMatches": [
    {
      "tabId": "CB9AF311-7E5A-441E-B1BE-F16AC10D6226",
      "tabName": "Agent Session Manager",
      "tabDirectory": "/Users/justinfuller/code/agent-session-manager",
      "paneId": "334076B4-6875-4785-9AEA-D108F499A1A7",
      "paneName": "telemetry-skill",
      "harness": "codex",
      "worktreeDirectory": "/Users/justinfuller/code/agent-session-manager/.agent-session-manager/worktrees/telemetry-skill"
    }
  ],
  "candidateTraceFiles": [
    {
      "path": "/Users/justinfuller/Library/Application Support/agent-session-manager/traces/Agent_Session_Manager-CB9AF311/telemetry-skill-334076B4.jsonl",
      "metadata": {
        "_type": "metadata",
        "paneId": "334076B4-6875-4785-9AEA-D108F499A1A7",
        "paneName": "telemetry-skill",
        "tabId": "CB9AF311-7E5A-441E-B1BE-F16AC10D6226",
        "tabName": "Agent Session Manager",
        "createdAt": "2026-06-01T13:12:00Z"
      }
    }
  ],
  "paneSpans": [
    {
      "name": "tab.worktree.resolved",
      "traceId": "473100f13b729fdb5743333d5a6b1a33",
      "spanId": "dc3d3e348d27e50c",
      "startEpochMs": 1780319520002,
      "endEpochMs": 1780319520002,
      "durationMs": 0,
      "attributes": {
        "pane.id": "334076B4-6875-4785-9AEA-D108F499A1A7",
        "pane.name": "telemetry-skill",
        "path": "/Users/justinfuller/code/agent-session-manager/.agent-session-manager/worktrees/telemetry-skill",
        "result": "dir: /Users/justinfuller/code/agent-session-manager/.agent-session-manager/worktrees/telemetry-skill",
        "tab.id": "CB9AF311-7E5A-441E-B1BE-F16AC10D6226",
        "tab.name": "Agent Session Manager",
        "user_ref": "telemetry-skill"
      }
    },
    {
      "name": "terminal.process.started",
      "traceId": "7fd5301eb66f1eb9b5baf36e4fd0304d",
      "spanId": "b9e76746c76c4a26",
      "startEpochMs": 1780319520032,
      "endEpochMs": 1780319520032,
      "durationMs": 0,
      "attributes": {
        "args": "-i -c codex --dangerously-bypass-approvals-and-sandbox",
        "executable": "/bin/zsh",
        "pane.id": "334076B4-6875-4785-9AEA-D108F499A1A7",
        "pane.name": "telemetry-skill",
        "tab.id": "CB9AF311-7E5A-441E-B1BE-F16AC10D6226",
        "tab.name": "Agent Session Manager",
        "working_directory": "/Users/justinfuller/code/agent-session-manager/.agent-session-manager/worktrees/telemetry-skill"
      }
    },
    {
      "name": "terminal.attention.delivered",
      "traceId": "005b6f9fb759f0e5e2375ef13b175e91",
      "spanId": "59c24679164c830c",
      "startEpochMs": 1780321753754,
      "endEpochMs": 1780321753754,
      "durationMs": 0,
      "attributes": {
        "pane.id": "334076B4-6875-4785-9AEA-D108F499A1A7",
        "pane.name": "telemetry-skill",
        "reason": "Attention needed",
        "source": "bell",
        "tab.id": "CB9AF311-7E5A-441E-B1BE-F16AC10D6226",
        "tab.name": "Agent Session Manager"
      }
    }
  ],
  "legacyFiles": [
    {
      "path": "/Users/justinfuller/Library/Application Support/agent-session-manager/debug-trace.log",
      "exists": true,
      "bytes": 1366288
    },
    {
      "path": "/Users/justinfuller/Library/Application Support/agent-session-manager/traces.jsonl",
      "exists": true,
      "bytes": 90331
    }
  ]
}
```

## Historical Pane With Invariant Violations

```bash
.agents/skills/agent-data-access/scripts/collect-telemetry.sh \
  --app prod \
  --pane-id D4C19E0C \
  --since 24h \
  --limit 2 |
jq '{candidateTraceFiles,matchingInvariantViolations,truncation}'
```

```json
{
  "candidateTraceFiles": [
    {
      "path": "/Users/justinfuller/Library/Application Support/agent-session-manager/traces/Agent_Session_Manager-CB9AF311/no-fake-screenshots-D4C19E0C.jsonl",
      "metadata": {
        "_type": "metadata",
        "paneId": "D4C19E0C-B420-4614-8EE1-712136E1D9FB",
        "paneName": "no-fake-screenshots",
        "tabId": "CB9AF311-7E5A-441E-B1BE-F16AC10D6226",
        "tabName": "Agent Session Manager",
        "createdAt": "2026-05-31T23:40:58Z"
      }
    }
  ],
  "matchingInvariantViolations": [
    {
      "description": "Displayed line counts must come from the pane's git diff.",
      "severity": "warning",
      "id": "E2EB884F-98EC-40E1-8642-8D081323D2CC",
      "timestamp": "2026-05-31T23:46:21Z",
      "integration": "Status Line",
      "invariantID": "statusline.lines.source",
      "context": {
        "reported_added": "772",
        "computed_removed": "0",
        "tab.id": "CB9AF311-7E5A-441E-B1BE-F16AC10D6226",
        "pane.name": "no-fake-screenshots",
        "pane.id": "D4C19E0C-B420-4614-8EE1-712136E1D9FB",
        "reported_removed": "540",
        "computed_added": "0",
        "tab.name": "Agent Session Manager"
      }
    },
    {
      "severity": "warning",
      "timestamp": "2026-05-31T23:46:24Z",
      "invariantID": "statusline.lines.source",
      "context": {
        "reported_added": "772",
        "computed_added": "0",
        "computed_removed": "0",
        "reported_removed": "540",
        "tab.id": "CB9AF311-7E5A-441E-B1BE-F16AC10D6226",
        "tab.name": "Agent Session Manager",
        "pane.name": "no-fake-screenshots",
        "pane.id": "D4C19E0C-B420-4614-8EE1-712136E1D9FB"
      },
      "integration": "Status Line",
      "id": "729A0333-E5C4-41D6-B39A-8518FC8F56CE",
      "description": "Displayed line counts must come from the pane's git diff."
    }
  ],
  "truncation": {
    "paneSpans": true,
    "matchingInvariantViolations": true,
    "correlatedGlobalSpans": true
  }
}
```

## Empty Development Directory

```bash
.agents/skills/agent-data-access/scripts/collect-telemetry.sh --app dev --list |
jq '{app,debugMode,candidateTraceFiles,legacyFiles}'
```

```json
{
  "app": "dev",
  "debugMode": {
    "settingsFile": "/Users/justinfuller/Library/Application Support/agent-session-manager.dev/debug-settings.json",
    "exists": false,
    "enabled": false,
    "raw": null
  },
  "candidateTraceFiles": [],
  "legacyFiles": [
    {
      "path": "/Users/justinfuller/Library/Application Support/agent-session-manager.dev/debug-trace.log",
      "exists": false,
      "bytes": 0
    },
    {
      "path": "/Users/justinfuller/Library/Application Support/agent-session-manager.dev/traces.jsonl",
      "exists": false,
      "bytes": 0
    }
  ]
}
```
