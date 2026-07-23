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
            environment: context.environment
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
            environment: context.environment
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
        config["mcp"] = [
            "agent-session-manager": [
                "type": "remote",
                "url": context.endpoint.absoluteString,
                "headers": [
                    "Authorization": "Bearer {env:\(context.tokenEnvironmentKey)}"
                ],
                "oauth": false,
                "enabled": true,
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: []) else {
            throw AgentControlHarnessInjectionError.invalidConfiguration(.opencode)
        }
        environment[index] = "OPENCODE_CONFIG_CONTENT=\(String(decoding: data, as: UTF8.self))"
        return AgentControlHarnessLaunchContext(
            endpoint: context.endpoint,
            tokenEnvironmentKey: context.tokenEnvironmentKey,
            commandArguments: context.commandArguments,
            environment: environment
        )
    }
}

struct CursorAgentControlAdapter: AgentControlHarnessAdapter {
    func prepare(_ context: AgentControlHarnessLaunchContext) throws -> AgentControlHarnessLaunchContext {
        throw AgentControlHarnessInjectionError.unsupported(.cursor)
    }
}

@MainActor
enum AgentControlHarnessInjection {
    static let tokenEnvironmentKey = "AGENT_SESSION_MANAGER_MCP_TOKEN"

    static func prepare(
        pane: Pane,
        tab: Tab,
        commandArguments: [String]?,
        environment: [String],
        appSettings: AppSettings?
    ) throws -> ([String]?, [String]) {
        guard pane.harness != .shell, pane.agentControlInjectionEnabled, appSettings != nil else {
            AgentControlService.shared.revoke(paneID: pane.id)
            recordPreparation(pane: pane, tab: tab, result: "disabled")
            return (commandArguments, environment)
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
                commandArguments: commandArguments ?? [],
                environment: environment + ["\(tokenEnvironmentKey)=\(credential.bearerToken)"]
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
            recordPreparation(pane: pane, tab: tab, result: "injected")
            return (commandArguments == nil ? nil : prepared.commandArguments, prepared.environment)
        } catch {
            AgentControlService.shared.revoke(
                paneID: pane.id, paneName: pane.name, tabID: tab.id, tabName: tab.name)
            recordPreparation(pane: pane, tab: tab, result: "failed", error: error.localizedDescription)
            throw error
        }
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
