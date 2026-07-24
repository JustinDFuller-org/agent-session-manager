import Foundation
import MCP

struct AgentControlCLIOptionInput: Codable, Sendable {
    let id: String
    let enabled: Bool
    let value: String?
    let values: [String]?
}

struct AgentControlEnvironmentInput: Codable, Sendable {
    let id: String
    let enabled: Bool
    let value: String
}

struct AgentControlProfileOptionPatch: Codable, Sendable {
    let id: String
    let enabled: Bool
    let value: String?
    let values: [String]?
    let showOnPaneCreate: Bool?
}

struct AgentControlProfileEnvironmentPatch: Codable, Sendable {
    let id: String
    let enabled: Bool
    let value: String?
    let showOnPaneCreate: Bool?
}

struct AgentControlProfileCreateArguments: Codable, Sendable {
    let name: String
    let harness: Harness
    let cliOptions: [AgentControlProfileOptionPatch]?
    let environment: [AgentControlProfileEnvironmentPatch]?
}

struct AgentControlProfileUpdateArguments: Codable, Sendable {
    let profileID: String
    let name: String?
    let harness: Harness?
    let cliOptions: [AgentControlProfileOptionPatch]?
    let environment: [AgentControlProfileEnvironmentPatch]?
}

struct AgentControlProfileIDArguments: Codable, Sendable {
    let profileID: String
}

struct AgentControlProfileReorderArguments: Codable, Sendable {
    let profileID: String
    let destinationIndex: Int
}

struct AgentControlHarnessEnabledArguments: Codable, Sendable {
    let harness: Harness
    let enabled: Bool
}

struct AgentControlCLIOptionConfigArguments: Codable, Sendable {
    let harness: Harness
    let optionID: String
    let isAvailable: Bool?
    let isDefaultEnabled: Bool?
    let presetValues: [String]?
    let allowsMultipleValues: Bool?
}

struct AgentControlGlobalStatusLineArguments: Codable {
    let configuration: StatusLineConfig
}

struct AgentControlProfileStatusLineArguments: Codable {
    let profileID: String
    let configuration: StatusLineConfig
}

struct AgentControlNotificationAckArguments: Codable, Sendable {
    let notificationID: String
}

struct AgentControlTabCreateArguments: Codable, Sendable {
    let name: String
    let directory: String
    let baseBranch: String?
}

struct AgentControlTabIDArguments: Codable, Sendable {
    let tabID: String
}

struct AgentControlTabReorderArguments: Codable, Sendable {
    let tabID: String
    let destinationIndex: Int
}

struct AgentControlPaneCreateArguments: Codable, Sendable {
    let tabID: String
    let worktreeRef: String
    let harness: Harness
    let profileID: String?
    let cliOptions: [AgentControlCLIOptionInput]?
    let environment: [AgentControlEnvironmentInput]?
    let defaultBranch: String?
    let baseRef: WorktreeBaseRef?
    let priority: Bool?
    let agentControlInjectionEnabled: Bool?
    let manageExistingWorktree: Bool?
}

struct AgentControlPaneIDArguments: Codable, Sendable {
    let paneID: String
}

struct AgentControlPaneCleanupArguments: Codable, Sendable {
    let paneID: String
    let cleanup: String?
}

struct AgentControlPaneReorderArguments: Codable, Sendable {
    let paneID: String
    let destinationIndex: Int
}

struct AgentControlTabCleanupArguments: Codable, Sendable {
    let tabID: String
    let cleanup: String?
}

struct AgentControlCleanupResult: Codable, Sendable {
    let paneID: UUID
    let status: String
    let error: String?
}

struct AgentControlMutationResult: Codable, Sendable {
    let operation: String
    let status: String
    let tabID: UUID?
    let paneID: UUID?
    let profileID: UUID?
    let activeTabID: UUID?
    let activePaneID: UUID?
    let focusedPaneID: UUID?
    let tabOrder: [UUID]?
    let paneOrder: [UUID]?
    let cleanup: [AgentControlCleanupResult]
    let tab: AgentControlTabSnapshot?
    let pane: AgentControlPaneSnapshot?
    let profile: AgentControlProfileSnapshot?
    let profileOrder: [UUID]?
    let harness: AgentControlHarnessSnapshot?
    let activeHarnesses: [Harness]?
    let statusLineConfiguration: StatusLineConfig?
    let acknowledgedNotificationID: UUID?
    let error: String?
}

@MainActor
final class AgentControlMutationRouter {
    let appState: AppState
    let appSettings: AppSettings

    private static let mutationNames: Set<String> = [
        "tabs.create", "tabs.delete", "tabs.focus", "tabs.reorder",
        "panes.create", "panes.delete", "panes.focus", "panes.restart", "panes.reorder",
        "profiles.create", "profiles.update", "profiles.delete", "profiles.reorder",
        "status_lines.update_global", "status_lines.update_profile", "status_lines.clear_profile_override",
        "notifications.acknowledge",
        "harnesses.set_enabled", "harnesses.configure_cli_option",
    ]

    init(appState: AppState, appSettings: AppSettings) {
        self.appState = appState
        self.appSettings = appSettings
    }

    func handles(_ name: String) -> Bool {
        Self.mutationNames.contains(name)
    }

    func tools() -> [Tool] {
        [
            Tool(
                name: "tabs.create",
                description: "Create a tab in the Agent Session Manager workspace. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "name": .object(["type": .string("string")]),
                        "directory": .object(["type": .string("string")]),
                        "baseBranch": .object(["type": .string("string")]),
                    ], required: ["name", "directory"])),
            Tool(
                name: "tabs.delete",
                description: "Delete a tab and optionally clean up its managed worktrees. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "tabID": .object(["type": .string("string")]),
                        "cleanup": .object([
                            "type": .string("string"),
                            "enum": .array([.string("keep"), .string("delete")]),
                        ]),
                    ], required: ["tabID"])),
            Tool(
                name: "tabs.focus",
                description: "Activate a visible tab.",
                inputSchema: Self.objectSchema(
                    properties: ["tabID": .object(["type": .string("string")])], required: ["tabID"])),
            Tool(
                name: "tabs.reorder",
                description: "Move a tab to an insertion index. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "tabID": .object(["type": .string("string")]),
                        "destinationIndex": .object(["type": .string("integer")]),
                    ], required: ["tabID", "destinationIndex"])),
            Tool(
                name: "panes.create",
                description: "Create a pane after resolving and preparing its worktree and harness.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "tabID": .object(["type": .string("string")]),
                        "worktreeRef": .object(["type": .string("string")]),
                        "harness": .object(["type": .string("string")]),
                        "profileID": .object(["type": .string("string")]),
                        "cliOptions": .object(["type": .string("array")]),
                        "environment": .object(["type": .string("array")]),
                        "defaultBranch": .object(["type": .string("string")]),
                        "baseRef": .object([
                            "type": .string("string"),
                            "enum": .array([.string("fresh"), .string("head")]),
                        ]),
                        "priority": .object(["type": .string("boolean")]),
                        "agentControlInjectionEnabled": .object(["type": .string("boolean")]),
                        "manageExistingWorktree": .object(["type": .string("boolean")]),
                    ], required: ["tabID", "worktreeRef", "harness"])),
            Tool(
                name: "panes.delete",
                description: "Delete a pane and optionally clean up its managed worktree.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "paneID": .object(["type": .string("string")]),
                        "cleanup": .object([
                            "type": .string("string"),
                            "enum": .array([.string("keep"), .string("delete")]),
                        ]),
                    ], required: ["paneID"])),
            Tool(
                name: "panes.focus",
                description: "Activate and focus a visible pane.",
                inputSchema: Self.objectSchema(
                    properties: ["paneID": .object(["type": .string("string")])], required: ["paneID"])),
            Tool(
                name: "panes.restart",
                description: "Restart a visible pane using its existing harness configuration.",
                inputSchema: Self.objectSchema(
                    properties: ["paneID": .object(["type": .string("string")])], required: ["paneID"])),
            Tool(
                name: "panes.reorder",
                description: "Move a pane within its current tab.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "paneID": .object(["type": .string("string")]),
                        "destinationIndex": .object(["type": .string("integer")]),
                    ], required: ["paneID", "destinationIndex"])),
            Tool(
                name: "profiles.create",
                description: "Create a reusable harness profile. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "name": .object(["type": .string("string")]),
                        "harness": .object(["type": .string("string")]),
                        "cliOptions": .object(["type": .string("array")]),
                        "environment": .object(["type": .string("array")]),
                    ], required: ["name", "harness"])),
            Tool(
                name: "profiles.update",
                description: "Patch a reusable harness profile. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "profileID": .object(["type": .string("string")]),
                        "name": .object(["type": .string("string")]),
                        "harness": .object(["type": .string("string")]),
                        "cliOptions": .object(["type": .string("array")]),
                        "environment": .object(["type": .string("array")]),
                    ], required: ["profileID"])),
            Tool(
                name: "profiles.delete",
                description: "Delete a reusable harness profile. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: ["profileID": .object(["type": .string("string")])], required: ["profileID"])),
            Tool(
                name: "profiles.reorder",
                description: "Move a profile to an insertion index. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "profileID": .object(["type": .string("string")]),
                        "destinationIndex": .object(["type": .string("integer")]),
                    ], required: ["profileID", "destinationIndex"])),
            Tool(
                name: "status_lines.update_global",
                description: "Replace the global status-line configuration. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: ["configuration": .object(["type": .string("object")])],
                    required: ["configuration"])),
            Tool(
                name: "status_lines.update_profile",
                description: "Replace a profile's custom status-line configuration. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "profileID": .object(["type": .string("string")]),
                        "configuration": .object(["type": .string("object")]),
                    ], required: ["profileID", "configuration"])),
            Tool(
                name: "status_lines.clear_profile_override",
                description: "Restore a profile's status line to the global configuration. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: ["profileID": .object(["type": .string("string")])],
                    required: ["profileID"])),
            Tool(
                name: "notifications.acknowledge",
                description: "Navigate to and acknowledge a visible notification.",
                inputSchema: Self.objectSchema(
                    properties: ["notificationID": .object(["type": .string("string")])],
                    required: ["notificationID"])),
            Tool(
                name: "harnesses.set_enabled",
                description: "Enable or disable a harness for future pane creation. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "harness": .object(["type": .string("string")]),
                        "enabled": .object(["type": .string("boolean")]),
                    ], required: ["harness", "enabled"])),
            Tool(
                name: "harnesses.configure_cli_option",
                description: "Update one harness CLI option catalog entry. Global scope required.",
                inputSchema: Self.objectSchema(
                    properties: [
                        "harness": .object(["type": .string("string")]),
                        "optionID": .object(["type": .string("string")]),
                        "isAvailable": .object(["type": .string("boolean")]),
                        "isDefaultEnabled": .object(["type": .string("boolean")]),
                        "presetValues": .object(["type": .string("array")]),
                        "allowsMultipleValues": .object(["type": .string("boolean")]),
                    ], required: ["harness", "optionID"])),
        ]
    }

    func callTool(
        name: String, arguments: [String: Value]?, source: AgentControlSource
    ) async throws -> CallTool.Result {
        do {
            try Task.checkCancellation()
            let value: AgentControlMutationResult
            switch name {
            case "tabs.create":
                try requireGlobal(source, name: name)
                value = try createTab(decode(AgentControlTabCreateArguments.self, arguments: arguments), source: source)
            case "tabs.delete":
                try requireGlobal(source, name: name)
                value = try await deleteTab(
                    decode(AgentControlTabCleanupArguments.self, arguments: arguments), source: source)
            case "tabs.focus":
                let args = try decode(AgentControlTabIDArguments.self, arguments: arguments)
                value = try focusTab(args, source: source)
            case "tabs.reorder":
                try requireGlobal(source, name: name)
                value = try reorderTab(
                    decode(AgentControlTabReorderArguments.self, arguments: arguments), source: source)
            case "panes.create":
                let args = try decode(AgentControlPaneCreateArguments.self, arguments: arguments)
                value = try await createPane(args, source: source)
            case "panes.delete":
                let args = try decode(AgentControlPaneCleanupArguments.self, arguments: arguments)
                value = try await deletePane(args, source: source)
            case "panes.focus":
                value = try focusPane(
                    decode(AgentControlPaneIDArguments.self, arguments: arguments), source: source)
            case "panes.restart":
                value = try restartPane(
                    decode(AgentControlPaneIDArguments.self, arguments: arguments), source: source)
            case "panes.reorder":
                value = try reorderPane(
                    decode(AgentControlPaneReorderArguments.self, arguments: arguments), source: source)
            case "profiles.create":
                try requireGlobal(source, name: name)
                value = try createProfile(
                    decode(AgentControlProfileCreateArguments.self, arguments: arguments), source: source)
            case "profiles.update":
                try requireGlobal(source, name: name)
                value = try updateProfile(
                    decode(AgentControlProfileUpdateArguments.self, arguments: arguments), source: source)
            case "profiles.delete":
                try requireGlobal(source, name: name)
                value = try deleteProfile(
                    decode(AgentControlProfileIDArguments.self, arguments: arguments), source: source)
            case "profiles.reorder":
                try requireGlobal(source, name: name)
                value = try reorderProfile(
                    decode(AgentControlProfileReorderArguments.self, arguments: arguments), source: source)
            case "status_lines.update_global":
                try requireGlobal(source, name: name)
                value = try updateGlobalStatusLine(
                    decode(AgentControlGlobalStatusLineArguments.self, arguments: arguments), source: source)
            case "status_lines.update_profile":
                try requireGlobal(source, name: name)
                value = try updateProfileStatusLine(
                    decode(AgentControlProfileStatusLineArguments.self, arguments: arguments), source: source)
            case "status_lines.clear_profile_override":
                try requireGlobal(source, name: name)
                value = try clearProfileStatusLine(
                    decode(AgentControlProfileIDArguments.self, arguments: arguments), source: source)
            case "notifications.acknowledge":
                value = try acknowledgeNotification(
                    decode(AgentControlNotificationAckArguments.self, arguments: arguments), source: source)
            case "harnesses.set_enabled":
                try requireGlobal(source, name: name)
                value = try setHarnessEnabled(
                    decode(AgentControlHarnessEnabledArguments.self, arguments: arguments), source: source)
            case "harnesses.configure_cli_option":
                try requireGlobal(source, name: name)
                value = try configureCLIOption(
                    decode(AgentControlCLIOptionConfigArguments.self, arguments: arguments), source: source)
            default:
                throw MCPError.invalidParams("Unknown Agent Session Manager mutation tool")
            }
            return try result(value)
        } catch is CancellationError {
            record(name: name, source: source, result: "cancelled")
            throw CancellationError()
        } catch let error as MCPError {
            record(name: name, source: source, result: "rejected")
            throw error
        } catch {
            record(name: name, source: source, result: "failed")
            throw MCPError.internalError(String(error.localizedDescription.prefix(200)))
        }
    }

    private func createTab(
        _ args: AgentControlTabCreateArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        let name = args.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw MCPError.invalidParams("Tab name must not be empty") }
        let directory = URL(filePath: args.directory).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue
        else {
            throw MCPError.invalidParams("Tab directory must exist and be a directory")
        }
        let baseBranch = args.baseBranch?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tab = Tab(
            name: name, directory: directory, baseBranchOverride: baseBranch?.isEmpty == true ? nil : baseBranch)
        appState.tabs.append(tab)
        appState.activeTabID = tab.id
        appState.activePaneID = nil
        SessionPersistence.save(appState: appState)
        let result = mutationResult(
            operation: "tabs.create", status: "succeeded", tabID: tab.id, tab: snapshotTab(tab, source: source))
        record(name: "tabs.create", source: source, result: "succeeded", tabID: tab.id)
        return result
    }

    private func focusTab(
        _ args: AgentControlTabIDArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        let tab = try visibleTab(id: args.tabID, source: source, operation: "tabs.focus")
        appState.switchToTab(id: tab.id, focusModeTabSwitchBehavior: appSettings.focusModeTabSwitchBehavior)
        SessionPersistence.save(appState: appState)
        let result = mutationResult(
            operation: "tabs.focus", status: "succeeded", tabID: tab.id,
            activeTabID: appState.activeTabID, activePaneID: appState.activePaneID,
            tab: snapshotTab(tab, source: source))
        record(name: "tabs.focus", source: source, result: "succeeded", tabID: tab.id)
        return result
    }

    private func reorderTab(
        _ args: AgentControlTabReorderArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        guard
            let tab = appState.tabs.first(where: { $0.id.uuidString.caseInsensitiveCompare(args.tabID) == .orderedSame }
            )
        else {
            throw MCPError.invalidParams("Tab was not found")
        }
        guard (0...appState.tabs.count).contains(args.destinationIndex) else {
            throw MCPError.invalidParams("Tab destination index is out of range")
        }
        guard let index = appState.tabs.firstIndex(where: { $0.id == tab.id }) else {
            throw MCPError.invalidParams("Tab was not found")
        }
        appState.moveTab(from: IndexSet(integer: index), to: args.destinationIndex)
        let result = mutationResult(
            operation: "tabs.reorder", status: "succeeded", tabID: tab.id, tabOrder: appState.tabs.map(\.id))
        record(name: "tabs.reorder", source: source, result: "succeeded", tabID: tab.id)
        return result
    }

    private func createPane(
        _ args: AgentControlPaneCreateArguments, source: AgentControlSource
    ) async throws -> AgentControlMutationResult {
        let tab = try visibleTab(id: args.tabID, source: source, operation: "panes.create")
        guard source.scope != .pane else {
            throw MCPError.invalidRequest("Pane scope cannot create another pane")
        }
        guard args.harness != .shell, appSettings.isActive(args.harness) else {
            throw MCPError.invalidParams("Harness is unavailable for pane creation")
        }
        let profile = try resolveProfile(args.profileID, harness: args.harness)
        let options = try resolveOptions(args.cliOptions, profile: profile, harness: args.harness)
        let environment = try resolveEnvironment(args.environment, profile: profile, harness: args.harness)
        let injection = appSettings.resolvedAgentControlInjectionDecision(
            persistedDecision: args.agentControlInjectionEnabled)
        let defaultBranch = resolveDefaultBranch(args.defaultBranch, tab: tab)
        let baseRef = args.baseRef ?? appSettings.worktreeBaseRef
        let worktreeRef = args.worktreeRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !worktreeRef.isEmpty else { throw MCPError.invalidParams("Worktree reference must not be empty") }

        try Task.checkCancellation()
        let resolved = try await tab.resolveOrAttachWorktree(
            userRef: worktreeRef, defaultBranch: defaultBranch, baseRef: baseRef)
        do {
            try Task.checkCancellation()
        } catch is CancellationError {
            if resolved.wasCreated {
                try? await tab.cleanupManagedWorktree(at: resolved.checkoutURL)
            }
            throw CancellationError()
        }
        let inUse = appState.isCheckoutInUse(
            directory: tab.directory, checkout: resolved.checkoutURL)
        guard !inUse else { throw MCPError.invalidRequest("A pane with this worktree is already open") }
        do {
            try Task.checkCancellation()
        } catch is CancellationError {
            if resolved.wasCreated {
                try? await tab.cleanupManagedWorktree(at: resolved.checkoutURL)
            }
            throw CancellationError()
        }

        let managed: Bool
        if resolved.isExternalTakeover {
            switch appSettings.existingWorktreeManagement {
            case .always: managed = true
            case .never: managed = false
            case .ask:
                guard let choice = args.manageExistingWorktree else {
                    throw MCPError.invalidRequest("manageExistingWorktree is required for an existing worktree")
                }
                managed = choice
            }
        } else {
            managed = true
        }

        tab.setFocusedPane(id: nil, reason: "agent_control_pane_created")
        let pane = tab.addPaneWithLoadingState(
            name: worktreeRef,
            harness: args.harness,
            worktreeIsManaged: managed,
            profileID: profile?.id,
            agentControlInjectionEnabled: injection,
            appSettings: appSettings)
        pane.bindNotifications(appState: appState, isPriority: args.priority ?? false)
        appState.setActivePane(id: pane.id)
        SessionPersistence.save(appState: appState)

        let effectiveArgs = Tab.applyAutoSessionName(
            tabName: tab.name, paneName: resolved.paneTitle, extraArgs: options,
            harness: args.harness, enabled: appSettings.autoSetSessionName)
        tab.completeSetup(
            for: pane,
            resolved: resolved,
            managed: managed,
            effectiveExtraArgs: effectiveArgs,
            extraEnvVars: environment,
            statusLineConfigOverride: profile?.statusLineConfig,
            appSettings: appSettings)
        SessionPersistence.save(appState: appState)

        let failed: String? = {
            guard case .failed(let error) = pane.setupState else { return nil }
            return error
        }()
        let status = failed == nil ? "succeeded" : "failed"
        let result = mutationResult(
            operation: "panes.create", status: status, tabID: tab.id, paneID: pane.id,
            activeTabID: appState.activeTabID, activePaneID: appState.activePaneID,
            pane: snapshotPane(pane), error: failed)
        record(name: "panes.create", source: source, result: status, tabID: tab.id, paneID: pane.id)
        return result
    }

    private func focusPane(
        _ args: AgentControlPaneIDArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        let pane = try visiblePane(id: args.paneID, source: source, operation: "panes.focus")
        guard let tab = pane.tab else { throw MCPError.internalError("Pane has no parent tab") }
        appState.switchToTab(id: tab.id, focusModeTabSwitchBehavior: .rememberFocus)
        appState.setActivePane(id: pane.id)
        tab.setFocusedPane(id: pane.id, reason: "agent_control")
        SessionPersistence.save(appState: appState)
        let result = mutationResult(
            operation: "panes.focus", status: "succeeded", tabID: tab.id, paneID: pane.id,
            activeTabID: appState.activeTabID, activePaneID: appState.activePaneID,
            focusedPaneID: tab.focusedPaneID, pane: snapshotPane(pane))
        record(name: "panes.focus", source: source, result: "succeeded", tabID: tab.id, paneID: pane.id)
        return result
    }

    private func restartPane(
        _ args: AgentControlPaneIDArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        let pane = try visiblePane(id: args.paneID, source: source, operation: "panes.restart")
        guard let tab = pane.tab else { throw MCPError.internalError("Pane has no parent tab") }
        guard pane.terminalController != nil else {
            throw MCPError.invalidRequest("Pane is not ready to restart")
        }
        let previousToken = pane.restartToken
        tab.restartPane(pane, appSettings: appSettings)
        guard pane.restartToken != previousToken else {
            throw MCPError.internalError("Pane restart did not complete")
        }
        SessionPersistence.save(appState: appState)
        let result = mutationResult(
            operation: "panes.restart", status: "succeeded", tabID: tab.id, paneID: pane.id,
            pane: snapshotPane(pane))
        record(name: "panes.restart", source: source, result: "succeeded", tabID: tab.id, paneID: pane.id)
        return result
    }

    private func reorderPane(
        _ args: AgentControlPaneReorderArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        let pane = try visiblePane(id: args.paneID, source: source, operation: "panes.reorder")
        guard let tab = pane.tab else { throw MCPError.internalError("Pane has no parent tab") }
        guard (0...tab.panes.count).contains(args.destinationIndex) else {
            throw MCPError.invalidParams("Pane destination index is out of range")
        }
        guard let index = tab.panes.firstIndex(where: { $0.id == pane.id }) else {
            throw MCPError.invalidParams("Pane was not found")
        }
        tab.movePane(from: IndexSet(integer: index), to: args.destinationIndex)
        SessionPersistence.save(appState: appState)
        let result = mutationResult(
            operation: "panes.reorder", status: "succeeded", tabID: tab.id, paneID: pane.id,
            paneOrder: tab.panes.map(\.id))
        record(name: "panes.reorder", source: source, result: "succeeded", tabID: tab.id, paneID: pane.id)
        return result
    }

    private func deletePane(
        _ args: AgentControlPaneCleanupArguments, source: AgentControlSource
    ) async throws -> AgentControlMutationResult {
        let pane = try visiblePane(id: args.paneID, source: source, operation: "panes.delete")
        guard let tab = pane.tab else { throw MCPError.internalError("Pane has no parent tab") }
        let cleanup = try cleanupDecision(args.cleanup, panes: [pane])
        let paneID = pane.id
        try Task.checkCancellation()
        tab.closePane(pane)
        SessionPersistence.save(appState: appState)
        let cleanupResults = await cleanupWorktrees(cleanup, panes: [pane], tab: tab)
        let status = cleanupResults.contains(where: { $0.status == "failed" }) ? "partial_failure" : "succeeded"
        let result = mutationResult(
            operation: "panes.delete", status: status, tabID: tab.id, paneID: paneID,
            cleanup: cleanupResults)
        record(name: "panes.delete", source: source, result: status, tabID: tab.id, paneID: paneID)
        return result
    }

    private func deleteTab(
        _ args: AgentControlTabCleanupArguments, source: AgentControlSource
    ) async throws -> AgentControlMutationResult {
        let tab = try visibleTab(id: args.tabID, source: source, operation: "tabs.delete")
        let panes = tab.panes
        let cleanup = try cleanupDecision(args.cleanup, panes: panes)
        let tabID = tab.id
        appState.closeTab(tab)
        let cleanupResults = await cleanupWorktrees(cleanup, panes: panes, tab: tab)
        let status = cleanupResults.contains(where: { $0.status == "failed" }) ? "partial_failure" : "succeeded"
        let result = mutationResult(
            operation: "tabs.delete", status: status, tabID: tabID,
            activeTabID: appState.activeTabID, activePaneID: appState.activePaneID,
            cleanup: cleanupResults)
        record(name: "tabs.delete", source: source, result: status, tabID: tabID)
        return result
    }

    private func cleanupDecision(_ requested: String?, panes: [Pane]) throws -> String {
        guard panes.contains(where: { $0.worktreeIsManaged }) else { return "keep" }
        switch appSettings.worktreeCleanupBehavior {
        case .ask:
            guard let requested else {
                throw MCPError.invalidRequest("cleanup is required for managed worktrees")
            }
            guard requested == "keep" || requested == "delete" else {
                throw MCPError.invalidParams("cleanup must be keep or delete")
            }
            return requested
        case .keep: return "keep"
        case .delete: return "delete"
        }
    }

    private func cleanupWorktrees(
        _ decision: String, panes: [Pane], tab: Tab
    ) async -> [AgentControlCleanupResult] {
        guard decision == "delete" else {
            return panes.filter(\.worktreeIsManaged).map {
                AgentControlCleanupResult(paneID: $0.id, status: "kept", error: nil)
            }
        }
        var results: [AgentControlCleanupResult] = []
        for pane in panes where pane.worktreeIsManaged {
            do {
                try await tab.cleanupWorktree(for: pane)
                results.append(AgentControlCleanupResult(paneID: pane.id, status: "deleted", error: nil))
            } catch {
                results.append(
                    AgentControlCleanupResult(
                        paneID: pane.id, status: "failed", error: String(error.localizedDescription.prefix(200))))
            }
        }
        return results
    }

    private func resolveProfile(_ rawID: String?, harness: Harness) throws -> Profile? {
        guard let rawID else { return nil }
        guard let id = UUID(uuidString: rawID), let profile = appSettings.profiles.first(where: { $0.id == id }) else {
            throw MCPError.invalidParams("Profile was not found")
        }
        guard profile.harness == harness else { throw MCPError.invalidParams("Profile harness does not match") }
        return profile
    }

    private func createProfile(
        _ args: AgentControlProfileCreateArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        let name = args.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw MCPError.invalidParams("Profile name must not be empty") }

        var profile = Profile(name: name, harness: args.harness)
        profile.cliOptions = defaultProfileCLIOptions(for: args.harness)
        profile.envVars = defaultProfileEnvironment(for: args.harness)
        try applyOptionPatches(args.cliOptions, to: &profile.cliOptions, harness: args.harness)
        try applyEnvironmentPatches(args.environment, to: &profile.envVars, harness: args.harness)

        appSettings.profiles.append(profile)
        guard SettingsPersistence.saveProfiles(appSettings: appSettings) else {
            appSettings.profiles.removeAll { $0.id == profile.id }
            throw MCPError.internalError("Profile could not be persisted")
        }

        record(name: "profiles.create", source: source, result: "succeeded", profileID: profile.id)
        return profileMutationResult(
            operation: "profiles.create", status: "succeeded", profile: profile)
    }

    private func updateProfile(
        _ args: AgentControlProfileUpdateArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        guard let profileID = UUID(uuidString: args.profileID),
            let index = appSettings.profiles.firstIndex(where: { $0.id == profileID })
        else { throw MCPError.invalidParams("Profile was not found") }

        let previous = appSettings.profiles[index]
        var updated = previous
        if let name = args.name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw MCPError.invalidParams("Profile name must not be empty") }
            updated.name = trimmed
        }

        let harnessChanged = args.harness.map { $0 != previous.harness } ?? false
        if let harness = args.harness {
            updated.harness = harness
            if harnessChanged {
                updated.cliOptions = defaultProfileCLIOptions(for: harness)
                updated.envVars = defaultProfileEnvironment(for: harness)
            }
        }
        try applyOptionPatches(args.cliOptions, to: &updated.cliOptions, harness: updated.harness)
        try applyEnvironmentPatches(args.environment, to: &updated.envVars, harness: updated.harness)

        appSettings.profiles[index] = updated
        guard SettingsPersistence.saveProfiles(appSettings: appSettings) else {
            appSettings.profiles[index] = previous
            throw MCPError.internalError("Profile could not be persisted")
        }

        record(name: "profiles.update", source: source, result: "succeeded", profileID: profileID)
        return profileMutationResult(
            operation: "profiles.update", status: "succeeded", profile: updated)
    }

    private func deleteProfile(
        _ args: AgentControlProfileIDArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        guard let profileID = UUID(uuidString: args.profileID),
            let index = appSettings.profiles.firstIndex(where: { $0.id == profileID })
        else { throw MCPError.invalidParams("Profile was not found") }

        let removed = appSettings.profiles.remove(at: index)
        guard SettingsPersistence.saveProfiles(appSettings: appSettings) else {
            appSettings.profiles.insert(removed, at: index)
            throw MCPError.internalError("Profile could not be persisted")
        }

        record(name: "profiles.delete", source: source, result: "succeeded", profileID: profileID)
        return mutationResult(
            operation: "profiles.delete", status: "succeeded", profileID: profileID,
            profileOrder: appSettings.profiles.map(\.id))
    }

    private func reorderProfile(
        _ args: AgentControlProfileReorderArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        guard let profileID = UUID(uuidString: args.profileID),
            let sourceIndex = appSettings.profiles.firstIndex(where: { $0.id == profileID })
        else { throw MCPError.invalidParams("Profile was not found") }
        guard (0..<appSettings.profiles.count).contains(args.destinationIndex) else {
            throw MCPError.invalidParams("Profile destination index is out of range")
        }

        let previous = appSettings.profiles
        let profile = appSettings.profiles.remove(at: sourceIndex)
        appSettings.profiles.insert(profile, at: args.destinationIndex)
        guard SettingsPersistence.saveProfiles(appSettings: appSettings) else {
            appSettings.profiles = previous
            throw MCPError.internalError("Profile order could not be persisted")
        }

        record(name: "profiles.reorder", source: source, result: "succeeded", profileID: profileID)
        return mutationResult(
            operation: "profiles.reorder", status: "succeeded", profileID: profileID,
            profileOrder: appSettings.profiles.map(\.id))
    }

    private func setHarnessEnabled(
        _ args: AgentControlHarnessEnabledArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        let previous = appSettings.activeTools
        appSettings.setActive(args.harness, args.enabled)
        guard SettingsPersistence.saveActiveTools(appSettings: appSettings) else {
            appSettings.activeTools = previous
            throw MCPError.internalError("Harness availability could not be persisted")
        }

        record(name: "harnesses.set_enabled", source: source, result: "succeeded", harness: args.harness)
        return mutationResult(
            operation: "harnesses.set_enabled", status: "succeeded",
            harness: AgentControlResourceRouter(appState: appState, appSettings: appSettings)
                .harnessSnapshots().first { $0.harness == args.harness },
            activeHarnesses: appSettings.activeHarnesses)
    }

    private func configureCLIOption(
        _ args: AgentControlCLIOptionConfigArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        guard args.harness != .shell else { throw MCPError.invalidParams("Shell has no CLI option catalog") }
        let previous = optionCatalog(for: args.harness)
        var updated = previous
        guard let index = updated.firstIndex(where: { $0.id == args.optionID }) else {
            throw MCPError.invalidParams("CLI option was not found")
        }

        if let isAvailable = args.isAvailable { updated[index].isAvailable = isAvailable }
        if let isDefaultEnabled = args.isDefaultEnabled { updated[index].isDefaultEnabled = isDefaultEnabled }
        if let presetValues = args.presetValues {
            updated[index].presetValues = CLIOptionConfig.normalizedPresetValues(presetValues)
        }
        if let allowsMultipleValues = args.allowsMultipleValues {
            updated[index].allowsMultipleValues = allowsMultipleValues
        }

        let persisted: Bool
        switch args.harness {
        case .claude:
            appSettings.cliOptions = updated
            persisted = SettingsPersistence.save(appSettings: appSettings)
        case .codex:
            appSettings.codexCliOptions = updated
            persisted = SettingsPersistence.saveCodexOptions(appSettings: appSettings)
        case .cursor:
            appSettings.cursorCliOptions = updated
            persisted = SettingsPersistence.saveCursorOptions(appSettings: appSettings)
        case .opencode:
            appSettings.opencodeCliOptions = updated
            persisted = SettingsPersistence.saveOpenCodeOptions(appSettings: appSettings)
        case .shell:
            persisted = false
        }
        guard persisted else {
            setOptionCatalog(previous, for: args.harness)
            throw MCPError.internalError("CLI option configuration could not be persisted")
        }

        record(
            name: "harnesses.configure_cli_option", source: source, result: "succeeded",
            harness: args.harness, optionID: args.optionID)
        return mutationResult(
            operation: "harnesses.configure_cli_option", status: "succeeded",
            harness: AgentControlResourceRouter(appState: appState, appSettings: appSettings)
                .harnessSnapshots().first { $0.harness == args.harness })
    }

    private func defaultProfileCLIOptions(for harness: Harness) -> [ProfileCLIOption] {
        optionCatalog(for: harness).filter { $0.isAvailable }.map {
            ProfileCLIOption(id: $0.id, isEnabled: $0.isDefaultEnabled)
        }
    }

    private func defaultProfileEnvironment(for harness: Harness) -> [ProfileEnvVar] {
        environmentCatalog(for: harness).filter { !$0.isAppControlled && $0.isAvailable }.map {
            ProfileEnvVar(id: $0.id, isEnabled: $0.isDefaultEnabled, value: $0.defaultValue)
        }
    }

    private func applyOptionPatches(
        _ patches: [AgentControlProfileOptionPatch]?, to options: inout [ProfileCLIOption], harness: Harness
    ) throws {
        guard let patches else { return }
        var seen = Set<String>()
        let catalog = optionCatalog(for: harness)
        for patch in patches {
            guard seen.insert(patch.id).inserted else {
                throw MCPError.invalidParams("CLI option was specified more than once: \(patch.id)")
            }
            guard let config = catalog.first(where: { $0.id == patch.id }) else {
                throw MCPError.invalidParams("Unknown CLI option: \(patch.id)")
            }
            let value = patch.value?.trimmingCharacters(in: .whitespaces)
            let values = patch.values?.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            switch config.optionType {
            case .boolean:
                guard value == nil || value?.isEmpty == true, values?.isEmpty != false else {
                    throw MCPError.invalidParams("Boolean CLI option cannot have a value: \(patch.id)")
                }
            case .string:
                guard config.allowsMultipleValues || values?.count ?? 0 <= 1 else {
                    throw MCPError.invalidParams("CLI option does not accept multiple values: \(patch.id)")
                }
            }
            let normalizedValue: String?
            let normalizedValues: [String]?
            if config.allowsMultipleValues {
                normalizedValue = value?.isEmpty == true ? nil : value
                normalizedValues = values?.isEmpty == true ? nil : values
            } else {
                normalizedValue = value?.isEmpty == true ? values?.first : value
                normalizedValues = nil
            }
            let existingIndex = options.firstIndex(where: { $0.id == patch.id })
            let current = existingIndex.map { options[$0] }
            let next = ProfileCLIOption(
                id: patch.id,
                isEnabled: patch.enabled,
                value: normalizedValue ?? current?.value,
                values: normalizedValues ?? current?.values,
                showOnPaneCreate: patch.showOnPaneCreate ?? current?.showOnPaneCreate ?? false)
            if let existingIndex { options[existingIndex] = next } else { options.append(next) }
        }
    }

    private func applyEnvironmentPatches(
        _ patches: [AgentControlProfileEnvironmentPatch]?, to environment: inout [ProfileEnvVar], harness: Harness
    ) throws {
        guard let patches else { return }
        var seen = Set<String>()
        let catalog = environmentCatalog(for: harness)
        for patch in patches {
            guard seen.insert(patch.id).inserted else {
                throw MCPError.invalidParams("Environment variable was specified more than once: \(patch.id)")
            }
            guard let config = catalog.first(where: { $0.id == patch.id }) else {
                throw MCPError.invalidParams("Unknown environment variable: \(patch.id)")
            }
            guard !config.isAppControlled else {
                throw MCPError.invalidRequest("App-controlled environment variables cannot be changed")
            }
            let existingIndex = environment.firstIndex(where: { $0.id == patch.id })
            let current = existingIndex.map { environment[$0] }
            let next = ProfileEnvVar(
                id: patch.id,
                isEnabled: patch.enabled,
                value: patch.value ?? current?.value ?? "",
                showOnPaneCreate: patch.showOnPaneCreate ?? current?.showOnPaneCreate ?? false)
            if let existingIndex { environment[existingIndex] = next } else { environment.append(next) }
        }
    }

    private func setOptionCatalog(_ options: [CLIOptionConfig], for harness: Harness) {
        switch harness {
        case .claude: appSettings.cliOptions = options
        case .codex: appSettings.codexCliOptions = options
        case .cursor: appSettings.cursorCliOptions = options
        case .opencode: appSettings.opencodeCliOptions = options
        case .shell: break
        }
    }

    func profileMutationResult(
        operation: String, status: String, profile: Profile
    ) -> AgentControlMutationResult {
        let resources = AgentControlResourceRouter(appState: appState, appSettings: appSettings)
        return mutationResult(
            operation: operation, status: status, profileID: profile.id,
            profileOrder: appSettings.profiles.map(\.id), profile: resources.profileSnapshot(profile))
    }

    private func resolveOptions(
        _ inputs: [AgentControlCLIOptionInput]?, profile: Profile?, harness: Harness
    ) throws -> [String] {
        let catalog = optionCatalog(for: harness)
        var states: [String: ProfileCLIOption] = [:]
        if let profile {
            for option in profile.cliOptions { states[option.id] = option }
        } else {
            for option in catalog where option.isAvailable && option.isDefaultEnabled {
                states[option.id] = ProfileCLIOption(id: option.id, isEnabled: true)
            }
        }
        for input in inputs ?? [] {
            guard let option = catalog.first(where: { $0.id == input.id }) else {
                throw MCPError.invalidParams("Unknown CLI option: \(input.id)")
            }
            states[input.id] = ProfileCLIOption(
                id: option.id, isEnabled: input.enabled, value: input.value, values: input.values)
        }
        var arguments: [String] = []
        for option in catalog {
            guard let state = states[option.id], state.isEnabled else { continue }
            arguments.append(contentsOf: option.commandLineArguments(value: state.value, values: state.values ?? []))
        }
        return arguments
    }

    private func resolveEnvironment(
        _ inputs: [AgentControlEnvironmentInput]?, profile: Profile?, harness: Harness
    ) throws -> [String: String] {
        let catalog = environmentCatalog(for: harness)
        var values: [String: String] = [:]
        if let profile {
            for value in profile.envVars where value.isEnabled && !value.value.isEmpty {
                values[value.id] = value.value
            }
        }
        for input in inputs ?? [] {
            guard let config = catalog.first(where: { $0.id == input.id }) else {
                throw MCPError.invalidParams("Unknown environment variable: \(input.id)")
            }
            guard !config.isAppControlled else {
                throw MCPError.invalidRequest("App-controlled environment variables cannot be overridden")
            }
            if input.enabled {
                values[input.id] = input.value
            } else {
                values.removeValue(forKey: input.id)
            }
        }
        return values
    }

    private func optionCatalog(for harness: Harness) -> [CLIOptionConfig] {
        switch harness {
        case .claude: return appSettings.cliOptions
        case .codex: return appSettings.codexCliOptions
        case .cursor: return appSettings.cursorCliOptions
        case .opencode: return appSettings.opencodeCliOptions
        case .shell: return []
        }
    }

    private func environmentCatalog(for harness: Harness) -> [EnvVarConfig] {
        switch harness {
        case .claude: return appSettings.envVarOptions
        case .opencode: return appSettings.opencodeEnvVarOptions
        case .codex, .cursor, .shell: return []
        }
    }

    private func resolveDefaultBranch(_ requested: String?, tab: Tab) -> String? {
        if let requested, !requested.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return requested }
        if let override = tab.baseBranchOverride, !override.isEmpty { return override }
        return appSettings.isDefaultBranchEnabled ? appSettings.defaultBranch : nil
    }

    private func visibleTab(id rawID: String, source: AgentControlSource, operation: String) throws -> Tab {
        guard let id = UUID(uuidString: rawID), let tab = appState.tabs.first(where: { $0.id == id }) else {
            throw MCPError.invalidParams("Tab was not found")
        }
        switch source.scope {
        case .global: return tab
        case .tab, .pane:
            guard tab.id == source.tabID else {
                throw MCPError.invalidRequest("\(operation) target is outside scope")
            }
            return tab
        }
    }

    private func visiblePane(id rawID: String, source: AgentControlSource, operation: String) throws -> Pane {
        guard let id = UUID(uuidString: rawID), let pane = appState.tabs.flatMap(\.panes).first(where: { $0.id == id })
        else {
            throw MCPError.invalidParams("Pane was not found")
        }
        switch source.scope {
        case .global: return pane
        case .tab:
            guard pane.tab?.id == source.tabID else {
                throw MCPError.invalidRequest("\(operation) target is outside scope")
            }
        case .pane:
            guard pane.id == source.paneID else {
                throw MCPError.invalidRequest("\(operation) target is outside scope")
            }
        }
        return pane
    }

    private func requireGlobal(_ source: AgentControlSource, name: String) throws {
        guard source.scope == .global else {
            record(name: name, source: source, result: "scope_denied")
            throw MCPError.invalidRequest("Global scope is required for this operation")
        }
    }

    private func snapshotTab(_ tab: Tab, source: AgentControlSource) -> AgentControlTabSnapshot {
        AgentControlResourceRouter(appState: appState, appSettings: appSettings).tabSnapshot(tab, source: source)
    }

    private func snapshotPane(_ pane: Pane) -> AgentControlPaneSnapshot {
        AgentControlResourceRouter(appState: appState, appSettings: appSettings).paneSnapshot(pane)
    }

    func mutationResult(
        operation: String,
        status: String,
        tabID: UUID? = nil,
        paneID: UUID? = nil,
        activeTabID: UUID? = nil,
        activePaneID: UUID? = nil,
        focusedPaneID: UUID? = nil,
        tabOrder: [UUID]? = nil,
        paneOrder: [UUID]? = nil,
        cleanup: [AgentControlCleanupResult] = [],
        tab: AgentControlTabSnapshot? = nil,
        pane: AgentControlPaneSnapshot? = nil,
        profileID: UUID? = nil,
        profileOrder: [UUID]? = nil,
        profile: AgentControlProfileSnapshot? = nil,
        harness: AgentControlHarnessSnapshot? = nil,
        activeHarnesses: [Harness]? = nil,
        statusLineConfiguration: StatusLineConfig? = nil,
        acknowledgedNotificationID: UUID? = nil,
        error: String? = nil
    ) -> AgentControlMutationResult {
        AgentControlMutationResult(
            operation: operation, status: status, tabID: tabID, paneID: paneID,
            profileID: profileID,
            activeTabID: activeTabID, activePaneID: activePaneID, focusedPaneID: focusedPaneID,
            tabOrder: tabOrder, paneOrder: paneOrder, cleanup: cleanup, tab: tab, pane: pane,
            profile: profile, profileOrder: profileOrder, harness: harness, activeHarnesses: activeHarnesses,
            statusLineConfiguration: statusLineConfiguration,
            acknowledgedNotificationID: acknowledgedNotificationID,
            error: error)
    }

    private func decode<T: Decodable>(_ type: T.Type, arguments: [String: Value]?) throws -> T {
        let data = try JSONEncoder().encode(arguments ?? [:])
        return try JSONDecoder().decode(type, from: data)
    }

    private func result(_ value: AgentControlMutationResult) throws -> CallTool.Result {
        let data = try JSONEncoder().encode(value)
        return try CallTool.Result(
            content: [.text(text: String(decoding: data, as: UTF8.self), annotations: nil, _meta: nil)],
            structuredContent: value)
    }

    func record(
        name: String, source: AgentControlSource, result: String, tabID: UUID? = nil, paneID: UUID? = nil,
        profileID: UUID? = nil, harness: Harness? = nil, optionID: String? = nil,
        notificationID: UUID? = nil
    ) {
        var attributes = [
            "tool": name,
            "result": result,
            "scope": source.scope.rawValue,
            "source.pane.id": source.paneID.uuidString,
            "source.tab.id": source.tabID.uuidString,
        ]
        if let tabID { attributes["target.tab.id"] = tabID.uuidString }
        if let paneID { attributes["target.pane.id"] = paneID.uuidString }
        if let profileID { attributes["target.profile.id"] = profileID.uuidString }
        if let harness { attributes["harness"] = harness.rawValue }
        if let optionID { attributes["option.id"] = optionID }
        if let notificationID { attributes["notification.id"] = notificationID.uuidString }
        TracingService.shared.record("agent_control.mutation", attributes: attributes)
    }

    private static func objectSchema(properties: [String: Value], required: [String]) -> Value {
        .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "properties": .object(properties),
            "required": .array(required.map(Value.string)),
        ])
    }
}
