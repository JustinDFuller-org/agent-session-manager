import Foundation

enum OhMyPiRuntimePlugin {
    static let directoryPrefix = "agent-session-manager-omp-"
    static let statusFilename = "status.json"
    static let extensionFilename = "main.mjs"

    static func prepare(paneID: UUID) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "\(directoryPrefix)\(paneID.uuidString.lowercased())-\(UUID().uuidString.lowercased())")
        let sourceURL = directory.appending(path: extensionFilename)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700])
            try Data(extensionSource.utf8).write(to: sourceURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: sourceURL.path)
            InvariantReporter.shared.check(
                .ohMyPiRuntimePluginPrivate,
                isPrivateRuntimeDirectory(directory, requiresMCP: false),
                context: ["result": "prepared"])
            return directory
        } catch {
            remove(directory: directory)
            throw error
        }
    }

    static func remove(directory: URL?) {
        guard let directory, isAppOwned(directory) else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    static func cleanupStaleRuntimes() {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: temporaryDirectory, includingPropertiesForKeys: nil)
        else {
            return
        }
        for child in children where isAppOwned(child) {
            remove(directory: child)
        }
    }

    static func isAppOwned(_ directory: URL) -> Bool {
        let standardizedDirectory = directory.standardizedFileURL
        let temporaryDirectory = FileManager.default.temporaryDirectory.standardizedFileURL
        guard standardizedDirectory.deletingLastPathComponent() == temporaryDirectory else { return false }

        let component = standardizedDirectory.lastPathComponent
        guard component.hasPrefix(directoryPrefix) else { return false }
        let suffix = component.dropFirst(directoryPrefix.count)
        guard let paneID = UUID(uuidString: String(suffix.prefix(36))),
            paneID.uuidString.lowercased() == suffix.prefix(36)
        else {
            return false
        }
        if suffix.count == 36 {
            return true
        }
        guard suffix.count == 73, suffix[suffix.index(suffix.startIndex, offsetBy: 36)] == "-" else {
            return false
        }
        let launchID = suffix.suffix(36)
        guard let uuid = UUID(uuidString: String(launchID)) else { return false }
        return uuid.uuidString.lowercased() == launchID
    }

    static func isPrivateRuntimeDirectory(_ directory: URL, requiresMCP: Bool) -> Bool {
        guard isAppOwned(directory) else { return false }
        let statusURL = directory.appending(path: statusFilename)
        let mcpURL = directory.appending(path: ".mcp.json")
        let requiredFiles =
            [directory, directory.appending(path: extensionFilename)]
            + (FileManager.default.fileExists(atPath: statusURL.path) ? [statusURL] : [])
            + (requiresMCP ? [mcpURL] : [])
        guard !requiresMCP || FileManager.default.fileExists(atPath: mcpURL.path) else { return false }
        return requiredFiles.allSatisfy { url in
            guard
                let mode = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions]
                    as? NSNumber
            else {
                return false
            }
            return mode.intValue & 0o777 == (url == directory ? 0o700 : 0o600)
        }
    }

    private static let extensionSource = #"""
        import { chmod, rename, writeFile } from "node:fs/promises";
        import { fileURLToPath } from "node:url";

        export default function agentSessionManagerExtension(pi) {
          const state = {
            attentionSequence: 0,
            eventSequence: 0,
            lastNamedSessionID: null,
            writeChain: Promise.resolve(),
            working: false,
          };
          const statusPath = process.env.AGENT_SESSION_MANAGER_OMP_STATUS_FILE
            ?? fileURLToPath(new URL("./status.json", import.meta.url));
          const cap = (value, limit = 256) => typeof value === "string" ? value.slice(0, limit) : null;
          const finite = (value) => typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : 0;
          const publish = (event, ctx, attention) => {
            state.writeChain = state.writeChain.then(async () => {
              const sessionManager = ctx.sessionManager;
              const sessionID = await sessionManager.getSessionId();
              const configuredName = process.env.AGENT_SESSION_MANAGER_OMP_SESSION_NAME;
              if (configuredName && sessionID !== state.lastNamedSessionID) {
                await sessionManager.setSessionName(configuredName.slice(0, 256));
                state.lastNamedSessionID = sessionID;
              }
              const usage = await sessionManager.getUsageStatistics();
              const context = await ctx.getContextUsage();
              const model = ctx.model;
              const sequence = ++state.eventSequence;
              const snapshot = {
                schema_version: 2,
                event_sequence: sequence,
                event,
                timestamp: new Date().toISOString(),
                session_id: cap(sessionID),
                session_persistent: Boolean(await sessionManager.getSessionFile()),
                session_name: cap(await sessionManager.getSessionName()),
                model_id: cap(model?.id),
                model_name: cap(model?.name ?? model?.displayName),
                model_provider: cap(model?.provider),
                thinking_level: cap(await pi.getThinkingLevel()),
                usage: {
                  input: finite(usage?.inputTokens),
                  output: finite(usage?.outputTokens),
                  cache_read: finite(usage?.cacheReadTokens),
                  cache_write: finite(usage?.cacheWriteTokens),
                  cost: finite(usage?.cost),
                },
                context: {
                  tokens: finite(context?.tokens),
                  context_window: finite(context?.contextWindow),
                  percent: finite(context?.percent),
                },
                is_working: state.working,
                attention: attention ? {
                  sequence: ++state.attentionSequence,
                  kind: attention.kind,
                  reason: cap(attention.reason, 200) ?? "",
                } : null,
              };
              const temporaryPath = `${statusPath}.${process.pid}.${sequence}.tmp`;
              await writeFile(temporaryPath, JSON.stringify(snapshot), { mode: 0o600 });
              await chmod(temporaryPath, 0o600);
              await rename(temporaryPath, statusPath);
              await chmod(statusPath, 0o600);
            }).catch((error) => {
              pi.logger.error(`Agent Session Manager status write failed: ${String(error).slice(0, 200)}`);
            });
            return state.writeChain;
          };

          pi.on("session_start", (_event, ctx) => publish("session_start", ctx));
          pi.on("session_switch", (_event, ctx) => publish("session_switch", ctx));
          pi.on("session_branch", (_event, ctx) => publish("session_branch", ctx));
          pi.on("agent_start", (_event, ctx) => { state.working = true; return publish("agent_start", ctx); });
          pi.on("agent_end", (event, ctx) => {
            if (!event.willContinue) state.working = false;
            return publish("agent_end", ctx, event.willContinue ? null : { kind: "finished", reason: "agent finished" });
          });
          pi.on("turn_end", (_event, ctx) => publish("turn_end", ctx));
          pi.on("session_shutdown", (_event, ctx) => { state.working = false; return publish("session_shutdown", ctx); });
          pi.on("input", (_event, ctx) => publish("input", ctx));
          pi.on("tool_approval_requested", (event, ctx) =>
            publish("tool_approval_requested", ctx, { kind: "permission", reason: `${event.toolName ?? "tool"}: ${event.reason ?? "approval requested"}` }));
          pi.on("tool_approval_resolved", (_event, ctx) => publish("tool_approval_resolved", ctx));
          pi.on("tool_call", (event, ctx) => {
            if (event.toolName === "ask" || event.toolName === "propose") {
              return publish("tool_call", ctx, { kind: "input", reason: event.toolName });
            }
          });
          pi.on("tool_result", (_event, ctx) => publish("tool_result", ctx));
        }
        """#
}
