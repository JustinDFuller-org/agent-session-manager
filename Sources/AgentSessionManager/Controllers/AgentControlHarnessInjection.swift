import Foundation

enum AgentControlHarnessInjectionError: LocalizedError, Equatable {
    case unavailable
    case unsupported(Harness)
    case invalidConfiguration(Harness)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Agent Session Manager control is unavailable. The control service has not started."
        case .unsupported(let harness):
            return "Agent Session Manager control injection is not supported for \(harness.displayName) yet. "
                + "Disable injection or use another harness."
        case .invalidConfiguration(let harness):
            return "Agent Session Manager could not prepare the \(harness.displayName) control configuration."
        }
    }
}

struct AgentControlHarnessLaunchContext {
    let endpoint: URL
    let tokenEnvironmentKey: String
    let commandArguments: [String]
    let environment: [String]
    let paneID: UUID
    let cursorPluginDirectory: URL?

    init(
        endpoint: URL,
        tokenEnvironmentKey: String,
        commandArguments: [String],
        environment: [String],
        paneID: UUID = UUID(),
        cursorPluginDirectory: URL? = nil
    ) {
        self.endpoint = endpoint
        self.tokenEnvironmentKey = tokenEnvironmentKey
        self.commandArguments = commandArguments
        self.environment = environment
        self.paneID = paneID
        self.cursorPluginDirectory = cursorPluginDirectory
    }
}

protocol AgentControlHarnessAdapter {
    func prepare(_ context: AgentControlHarnessLaunchContext) throws -> AgentControlHarnessLaunchContext
}

struct ClaudeAgentControlAdapter: AgentControlHarnessAdapter {
    func prepare(_ context: AgentControlHarnessLaunchContext) throws -> AgentControlHarnessLaunchContext {
        let config: [String: Any] = [
            "agent-session-manager": [
                "type": "http",
                "url": context.endpoint.absoluteString,
                "headers": [
                    "Authorization": "Bearer ${\(context.tokenEnvironmentKey)}"
                ],
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: []) else {
            throw AgentControlHarnessInjectionError.invalidConfiguration(.claude)
        }
        var arguments = context.commandArguments
        arguments.append(contentsOf: ["--mcp-config", String(decoding: data, as: UTF8.self)])
        return AgentControlHarnessLaunchContext(
            endpoint: context.endpoint,
            tokenEnvironmentKey: context.tokenEnvironmentKey,
            commandArguments: arguments,
            environment: context.environment,
            paneID: context.paneID,
            cursorPluginDirectory: context.cursorPluginDirectory
        )
    }
}

struct CodexAgentControlAdapter: AgentControlHarnessAdapter {
    func prepare(_ context: AgentControlHarnessLaunchContext) throws -> AgentControlHarnessLaunchContext {
        var arguments = context.commandArguments
        let prefix = "mcp_servers.agent_session_manager"
        arguments.append(contentsOf: [
            "-c", "\(prefix).url=\"\(context.endpoint.absoluteString)\"",
            "-c", "\(prefix).bearer_token_env_var=\"\(context.tokenEnvironmentKey)\"",
            "-c", "\(prefix).enabled=true",
        ])
        return AgentControlHarnessLaunchContext(
            endpoint: context.endpoint,
            tokenEnvironmentKey: context.tokenEnvironmentKey,
            commandArguments: arguments,
            environment: context.environment,
            paneID: context.paneID,
            cursorPluginDirectory: context.cursorPluginDirectory
        )
    }
}

struct OpenCodeAgentControlAdapter: AgentControlHarnessAdapter {
    func prepare(_ context: AgentControlHarnessLaunchContext) throws -> AgentControlHarnessLaunchContext {
        var environment = context.environment
        guard let index = environment.firstIndex(where: { $0.hasPrefix("OPENCODE_CONFIG_CONTENT=") }) else {
            throw AgentControlHarnessInjectionError.invalidConfiguration(.opencode)
        }
        let current = String(environment[index].dropFirst("OPENCODE_CONFIG_CONTENT=".count))
        guard var config = try JSONSerialization.jsonObject(with: Data(current.utf8)) as? [String: Any] else {
            throw AgentControlHarnessInjectionError.invalidConfiguration(.opencode)
        }
        var mcp: [String: Any]
        if let existing = config["mcp"] {
            guard let existingMCP = existing as? [String: Any] else {
                throw AgentControlHarnessInjectionError.invalidConfiguration(.opencode)
            }
            mcp = existingMCP
        } else {
            mcp = [:]
        }
        mcp["agent-session-manager"] = [
            "type": "remote",
            "url": context.endpoint.absoluteString,
            "headers": [
                "Authorization": "Bearer {env:\(context.tokenEnvironmentKey)}"
            ],
            "oauth": false,
            "enabled": true,
        ]
        config["mcp"] = mcp
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: []) else {
            throw AgentControlHarnessInjectionError.invalidConfiguration(.opencode)
        }
        environment[index] = "OPENCODE_CONFIG_CONTENT=\(String(decoding: data, as: UTF8.self))"
        return AgentControlHarnessLaunchContext(
            endpoint: context.endpoint,
            tokenEnvironmentKey: context.tokenEnvironmentKey,
            commandArguments: context.commandArguments,
            environment: environment,
            paneID: context.paneID,
            cursorPluginDirectory: context.cursorPluginDirectory
        )
    }
}

enum CursorAgentControlPlugin {
    static let directoryPrefix = "agent-session-manager-cursor-mcp-"

    static func directory(for paneID: UUID) -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "\(directoryPrefix)\(paneID.uuidString.lowercased())")
    }

    static func remove(directory: URL?) {
        guard let directory, isAppOwned(directory) else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    static func isAppOwned(_ directory: URL) -> Bool {
        directory.lastPathComponent.hasPrefix(directoryPrefix)
    }
}

struct CursorAgentControlAdapter: AgentControlHarnessAdapter {
    func prepare(_ context: AgentControlHarnessLaunchContext) throws -> AgentControlHarnessLaunchContext {
        let directory = CursorAgentControlPlugin.directory(for: context.paneID)
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(
                at: directory.appending(path: ".cursor-plugin"),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try fileManager.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: directory.path)

            let plugin = [
                "name": "agent-session-manager-\(context.paneID.uuidString.lowercased())",
                "version": "1.0.0",
            ]
            let pluginData = try JSONSerialization.data(withJSONObject: plugin, options: [])
            let pluginPath = directory.appending(path: ".cursor-plugin/plugin.json")
            try pluginData.write(to: pluginPath, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: pluginPath.path)

            let serverName = "agent-session-manager-\(context.paneID.uuidString.lowercased())"
            let mcp: [String: Any] = [
                "mcpServers": [
                    serverName: [
                        "url": context.endpoint.absoluteString,
                        "headers": [
                            "Authorization": "Bearer ${env:\(context.tokenEnvironmentKey)}"
                        ],
                    ]
                ]
            ]
            let mcpData = try JSONSerialization.data(withJSONObject: mcp, options: [])
            let mcpPath = directory.appending(path: "mcp.json")
            try mcpData.write(to: mcpPath, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: mcpPath.path)
        } catch {
            CursorAgentControlPlugin.remove(directory: directory)
            throw AgentControlHarnessInjectionError.invalidConfiguration(.cursor)
        }

        var arguments = context.commandArguments
        arguments.append(contentsOf: ["--plugin-dir", directory.path])
        return AgentControlHarnessLaunchContext(
            endpoint: context.endpoint,
            tokenEnvironmentKey: context.tokenEnvironmentKey,
            commandArguments: arguments,
            environment: context.environment,
            paneID: context.paneID,
            cursorPluginDirectory: directory)
    }
}

@MainActor
enum AgentControlHarnessInjection {
    nonisolated static let tokenEnvironmentKey = "AGENT_SESSION_MANAGER_MCP_TOKEN"

    static func prepare(
        pane: Pane,
        tab: Tab,
        commandArguments: [String]?,
        environment: [String],
        appSettings: AppSettings?
    ) throws -> ([String]?, [String]) {
        let sanitizedCommandArguments = commandArguments.map {
            removingControlArguments(from: $0, harness: pane.harness)
        }
        let sanitizedEnvironment = removingControlToken(from: environment)
        guard pane.harness != .shell, pane.agentControlInjectionEnabled, appSettings != nil else {
            CursorAgentControlPlugin.remove(directory: pane.cursorAgentControlPluginDirectory)
            pane.cursorAgentControlPluginDirectory = nil
            AgentControlService.shared.revoke(paneID: pane.id)
            recordPreparation(pane: pane, tab: tab, result: "disabled")
            return (sanitizedCommandArguments, sanitizedEnvironment)
        }
        let settings = appSettings!
        let source = AgentControlSource(
            paneID: pane.id,
            paneName: pane.name,
            tabID: tab.id,
            tabName: tab.name,
            scope: settings.agentControlScope
        )
        do {
            let credential = try AgentControlService.shared.register(source: source)
            let context = AgentControlHarnessLaunchContext(
                endpoint: credential.endpoint,
                tokenEnvironmentKey: tokenEnvironmentKey,
                commandArguments: sanitizedCommandArguments ?? [],
                environment: sanitizedEnvironment + ["\(tokenEnvironmentKey)=\(credential.bearerToken)"],
                paneID: pane.id
            )
            let adapter: any AgentControlHarnessAdapter
            switch pane.harness {
            case .claude: adapter = ClaudeAgentControlAdapter()
            case .codex: adapter = CodexAgentControlAdapter()
            case .cursor: adapter = CursorAgentControlAdapter()
            case .opencode: adapter = OpenCodeAgentControlAdapter()
            case .shell: throw AgentControlHarnessInjectionError.unsupported(.shell)
            }
            let prepared = try adapter.prepare(context)
            if pane.cursorAgentControlPluginDirectory != prepared.cursorPluginDirectory {
                CursorAgentControlPlugin.remove(directory: pane.cursorAgentControlPluginDirectory)
            }
            pane.cursorAgentControlPluginDirectory = prepared.cursorPluginDirectory
            recordPreparation(pane: pane, tab: tab, result: "injected")
            return (commandArguments == nil ? nil : prepared.commandArguments, prepared.environment)
        } catch {
            CursorAgentControlPlugin.remove(directory: pane.cursorAgentControlPluginDirectory)
            pane.cursorAgentControlPluginDirectory = nil
            AgentControlService.shared.revoke(
                paneID: pane.id, paneName: pane.name, tabID: tab.id, tabName: tab.name)
            if pane.harness == .cursor {
                recordPreparation(pane: pane, tab: tab, result: "fallback", error: error.localizedDescription)
                return (
                    commandArguments.map {
                        removingControlArguments(from: $0, harness: pane.harness)
                    }, sanitizedEnvironment
                )
            }
            recordPreparation(pane: pane, tab: tab, result: "failed", error: error.localizedDescription)
            throw error
        }
    }

    nonisolated static func removingControlToken(from environment: [String]) -> [String] {
        environment.filter { !$0.hasPrefix("\(tokenEnvironmentKey)=") }
    }

    nonisolated static func removingControlArguments(from arguments: [String], harness: Harness) -> [String] {
        var sanitized: [String] = []
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if harness == .claude, argument == "--mcp-config",
                index + 1 < arguments.count,
                arguments[index + 1].contains("agent-session-manager")
            {
                index += 2
                continue
            }
            if harness == .codex, argument == "-c",
                index + 1 < arguments.count,
                arguments[index + 1].hasPrefix("mcp_servers.agent_session_manager.")
            {
                index += 2
                continue
            }
            if harness == .cursor, argument == "--plugin-dir",
                index + 1 < arguments.count,
                CursorAgentControlPlugin.isAppOwned(URL(filePath: arguments[index + 1]))
            {
                index += 2
                continue
            }
            if harness == .cursor, argument.hasPrefix("--plugin-dir="),
                CursorAgentControlPlugin.isAppOwned(
                    URL(filePath: String(argument.dropFirst("--plugin-dir=".count))))
            {
                index += 1
                continue
            }
            sanitized.append(argument)
            index += 1
        }
        return sanitized
    }

    private static func recordPreparation(
        pane: Pane, tab: Tab, result: String, error: String? = nil
    ) {
        var attributes = [
            "pane.id": pane.id.uuidString,
            "pane.name": pane.name,
            "tab.id": tab.id.uuidString,
            "tab.name": tab.name,
            "harness": pane.harness.rawValue,
            "result": result,
        ]
        if let error { attributes["error"] = String(error.prefix(200)) }
        TracingService.shared.record("agent_control.harness.prepare", attributes: attributes)
    }
}

extension Tab {
    @discardableResult
    func prepareAgentControl(
        for pane: Pane, controller: TerminalController, appSettings: AppSettings?
    ) -> Bool {
        do {
            let prepared = try AgentControlHarnessInjection.prepare(
                pane: pane,
                tab: self,
                commandArguments: controller.pendingCommandArgs,
                environment: controller.pendingEnvironment ?? [],
                appSettings: appSettings ?? pane.appSettings
            )
            controller.pendingCommandArgs = prepared.0
            controller.pendingEnvironment = prepared.1
            return true
        } catch {
            pane.setupState = .failed(error: error.localizedDescription)
            return false
        }
    }
}
