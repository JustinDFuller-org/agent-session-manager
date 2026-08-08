import Foundation

enum OhMyPiRuntimePlugin {
    static let directoryPrefix = "agent-session-manager-omp-"
    static let statusFilename = "status.json"

    static func prepare(paneID: UUID) throws -> URL {
        let root = directory(for: paneID)
        remove(directory: root)

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(
                at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try fileManager.createDirectory(
                at: root.appending(path: "src"), withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.appending(path: "src").path)

            let manifest: [String: Any] = [
                "name": "agent-session-manager-\(paneID.uuidString.lowercased())",
                "version": "1.0.0",
                "omp": ["extensions": ["./src/main.ts"]],
            ]
            let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
            let packageURL = root.appending(path: "package.json")
            try manifestData.write(to: packageURL, options: .atomic)

            let statusURL = root.appending(path: statusFilename)
            try Data().write(to: statusURL, options: .atomic)
            let sourceURL = root.appending(path: "src/main.ts")
            try Data(extensionSource.utf8).write(to: sourceURL, options: .atomic)

            for file in [packageURL, statusURL, sourceURL] {
                try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            }
            InvariantReporter.shared.check(
                .ohMyPiRuntimePluginPrivate,
                isPrivateRuntimeDirectory(root, requiresMCP: false),
                context: ["result": "prepared"])
            return root
        } catch {
            remove(directory: root)
            throw error
        }
    }

    static func directory(for paneID: UUID) -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "\(directoryPrefix)\(paneID.uuidString.lowercased())", directoryHint: .isDirectory)
    }

    static func remove(directory: URL?) {
        guard let directory, isAppOwned(directory) else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    static func isAppOwned(_ directory: URL) -> Bool {
        let standardizedDirectory = directory.standardizedFileURL
        let temporaryDirectory = FileManager.default.temporaryDirectory.standardizedFileURL
        guard standardizedDirectory.deletingLastPathComponent() == temporaryDirectory else { return false }
        let component = standardizedDirectory.lastPathComponent
        guard component.hasPrefix(directoryPrefix) else { return false }
        let paneIDString = String(component.dropFirst(directoryPrefix.count))
        guard let paneID = UUID(uuidString: paneIDString) else { return false }
        return paneID.uuidString.lowercased() == paneIDString
    }

    static func isPrivateRuntimeDirectory(_ directory: URL, requiresMCP: Bool) -> Bool {
        guard isAppOwned(directory) else { return false }
        let files =
            [
                directory,
                directory.appending(path: "package.json"),
                directory.appending(path: statusFilename),
                directory.appending(path: "src/main.ts"),
            ] + (requiresMCP ? [directory.appending(path: "mcp.json")] : [])
        return files.allSatisfy { url in
            guard
                let mode = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions]
                    as? NSNumber
            else { return false }
            let expected: Int = url == directory ? 0o700 : 0o600
            return mode.intValue & 0o777 == expected
        }
    }

    private static let extensionSource = #"""
        import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
        import { writeFile, rename } from "node:fs/promises";
        import { join } from "node:path";

        export default function agentSessionManagerExtension(pi: ExtensionAPI) {
          const statusPath = join(import.meta.dirname, "..", "status.json");
          let sequence = 0;
          let attentionSequence = 0;
          let lastNamedSessionID: string | undefined;
          let working = false;

          const cap = (value: unknown, limit = 256) => typeof value === "string" ? value.slice(0, limit) : null;
          const nonnegative = (value: unknown) => typeof value === "number" && Number.isFinite(value) ? Math.max(0, value) : 0;
          const write = async (event: string, attention?: { kind: "finished" | "permission" | "input"; reason: string }) => {
            try {
              const sessionID = await pi.sessionManager.getSessionId();
              const sessionFile = await pi.sessionManager.getSessionFile();
              const usage = await pi.sessionManager.getUsageStatistics();
              const model = (await pi.models.current()) ?? pi.model;
              const context = await pi.getContextUsage();
              const snapshot = {
                schema_version: 1,
                event_sequence: ++sequence,
                event,
                timestamp: new Date().toISOString(),
                session_id: cap(sessionID),
                session_persistent: sessionFile != null,
                session_name: cap(await pi.sessionManager.getSessionName()),
                model_id: cap(model?.id),
                model_display_name: cap(model?.displayName),
                thinking_level: cap(await pi.getThinkingLevel()),
                usage: { input: nonnegative(usage?.inputTokens), output: nonnegative(usage?.outputTokens), cost: nonnegative(usage?.cost) },
                latest_request_usage: { input: 0, output: 0, cache_read: 0, cache_write: 0 },
                context: { tokens: nonnegative(context?.tokens), context_window: nonnegative(context?.contextWindow), percent: nonnegative(context?.percent) },
                is_working: working,
                attention: attention ? { sequence: ++attentionSequence, kind: attention.kind, reason: cap(attention.reason, 200) ?? "" } : null,
              };
              const temporaryPath = `${statusPath}.${process.pid}.tmp`;
              await writeFile(temporaryPath, JSON.stringify(snapshot), { mode: 0o600 });
              await rename(temporaryPath, statusPath);
            } catch (error) {
              pi.logger.error(`Agent Session Manager status write failed: ${String(error).slice(0, 200)}`);
            }
          };

          pi.on("session_start", () => write("session_start"));
          pi.on("session_switch", () => write("session_switch"));
          pi.on("session_branch", () => write("session_branch"));
          pi.on("agent_start", () => { working = true; return write("agent_start"); });
          pi.on("agent_end", (event: { willContinue?: boolean }) => {
            if (event.willContinue) return write("agent_end");
            working = false;
            return write("agent_end", { kind: "finished", reason: "agent finished" });
          });
          pi.on("turn_end", () => write("turn_end"));
          pi.on("session_shutdown", () => { working = false; return write("session_shutdown"); });
          pi.on("input", async () => {
            const sessionID = await pi.sessionManager.getSessionId();
            const configuredName = process.env.AGENT_SESSION_MANAGER_OMP_SESSION_NAME;
            if (configuredName && sessionID !== lastNamedSessionID) {
              await pi.setSessionName(configuredName.slice(0, 256));
              lastNamedSessionID = sessionID;
            }
            await write("input");
          });
          pi.on("tool_approval_requested", (event: { toolName?: string; reason?: string }) => write("tool_approval_requested", { kind: "permission", reason: `${event.toolName ?? "tool"}: ${event.reason ?? "approval requested"}` }));
          pi.on("tool_approval_resolved", () => write("tool_approval_resolved"));
          pi.on("tool_call", (event: { toolName?: string; input?: { path?: string } }) => {
            if (event.toolName === "ask" || (event.toolName === "write" && event.input?.path === "xd://propose")) {
              return write("tool_call", { kind: "input", reason: event.toolName });
            }
            return undefined;
          });
          pi.on("tool_result", () => write("tool_result"));
        }
        """#
}
