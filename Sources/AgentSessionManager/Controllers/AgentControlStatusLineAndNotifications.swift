import Foundation
import MCP

@MainActor
extension AgentControlMutationRouter {
    func visibleNotification(
        id rawID: String, source: AgentControlSource, operation: String
    ) throws -> PaneNotification {
        guard let id = UUID(uuidString: rawID),
            let notification = appState.notifications.first(where: { $0.id == id })
        else {
            throw MCPError.invalidParams("Notification was not found")
        }
        switch source.scope {
        case .global:
            return notification
        case .tab:
            guard notification.tabID == source.tabID else {
                throw MCPError.invalidRequest("\(operation) target is outside scope")
            }
        case .pane:
            guard notification.paneID == source.paneID else {
                throw MCPError.invalidRequest("\(operation) target is outside scope")
            }
        }
        return notification
    }

    func updateGlobalStatusLine(
        _ args: AgentControlGlobalStatusLineArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        try args.configuration.validateForAgentControl()
        let previous = appSettings.statusLineConfig
        appSettings.statusLineConfig = args.configuration
        guard SettingsPersistence.saveStatusLine(appSettings: appSettings) else {
            appSettings.statusLineConfig = previous
            throw MCPError.internalError("Global status-line configuration could not be persisted")
        }

        record(name: "status_lines_update_global", source: source, result: "succeeded")
        return mutationResult(
            operation: "status_lines_update_global", status: "succeeded",
            statusLineConfiguration: args.configuration)
    }

    func updateProfileStatusLine(
        _ args: AgentControlProfileStatusLineArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        try args.configuration.validateForAgentControl()
        guard let profileID = UUID(uuidString: args.profileID),
            let index = appSettings.profiles.firstIndex(where: { $0.id == profileID })
        else {
            throw MCPError.invalidParams("Profile was not found")
        }

        let previous = appSettings.profiles[index]
        var updated = previous
        updated.statusLineConfig = args.configuration
        appSettings.profiles[index] = updated
        guard SettingsPersistence.saveProfiles(appSettings: appSettings) else {
            appSettings.profiles[index] = previous
            throw MCPError.internalError("Profile status-line configuration could not be persisted")
        }

        record(name: "status_lines_update_profile", source: source, result: "succeeded", profileID: profileID)
        return profileMutationResult(
            operation: "status_lines_update_profile", status: "succeeded", profile: updated)
    }

    func clearProfileStatusLine(
        _ args: AgentControlProfileIDArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        guard let profileID = UUID(uuidString: args.profileID),
            let index = appSettings.profiles.firstIndex(where: { $0.id == profileID })
        else {
            throw MCPError.invalidParams("Profile was not found")
        }

        let previous = appSettings.profiles[index]
        var updated = previous
        updated.statusLineConfig = nil
        appSettings.profiles[index] = updated
        guard SettingsPersistence.saveProfiles(appSettings: appSettings) else {
            appSettings.profiles[index] = previous
            throw MCPError.internalError("Profile status-line configuration could not be persisted")
        }

        record(name: "status_lines_clear_profile_override", source: source, result: "succeeded", profileID: profileID)
        return profileMutationResult(
            operation: "status_lines_clear_profile_override", status: "succeeded", profile: updated)
    }

    func acknowledgeNotification(
        _ args: AgentControlNotificationAckArguments, source: AgentControlSource
    ) throws -> AgentControlMutationResult {
        let notification = try visibleNotification(
            id: args.notificationID, source: source, operation: "notifications_acknowledge")
        guard appState.acknowledgeNotification(id: notification.id) != nil else {
            throw MCPError.invalidRequest("Notification target no longer exists")
        }

        record(
            name: "notifications_acknowledge", source: source, result: "succeeded",
            tabID: notification.tabID, paneID: notification.paneID,
            notificationID: notification.id)
        return mutationResult(
            operation: "notifications_acknowledge", status: "succeeded",
            tabID: notification.tabID, paneID: notification.paneID,
            activeTabID: appState.activeTabID, activePaneID: appState.activePaneID,
            acknowledgedNotificationID: notification.id)
    }
}
