import Foundation

extension AgentControlMutationRouter {
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
}
