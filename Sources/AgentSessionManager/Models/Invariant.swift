import Foundation

struct Invariant: Identifiable, Hashable, Sendable {
    enum Severity: String, Codable, Sendable {
        case warning
        case error
    }

    let id: String
    let integration: String
    let severity: Severity
    let description: String
    let traceEventName: String?

    static let statusLineWorktreeName = Invariant(
        id: "statusline.worktree.name",
        integration: "Status Line",
        severity: .warning,
        description: "The reported worktree name must match the pane working directory.",
        traceEventName: "statusline.worktree.name_mismatch"
    )

    static let statusLineLinesSource = Invariant(
        id: "statusline.lines.source",
        integration: "Status Line",
        severity: .warning,
        description: "Displayed line counts must come from the pane's git diff.",
        traceEventName: "statusline.lines.source_mismatch"
    )

    static let appBundleIdentityPreferredURL = Invariant(
        id: "app.bundle_identity.preferred_url",
        integration: "App Bundle",
        severity: .warning,
        description: "Launch Services must prefer the running app bundle URL for its bundle identifier.",
        traceEventName: "app.bundle_identity.preferred_url_mismatch"
    )

    static let opencodeConfigContentAppControlled = Invariant(
        id: "opencode.config_content.app_controlled",
        integration: "OpenCode",
        severity: .warning,
        description: """
            OPENCODE_CONFIG_CONTENT and OPENCODE_PERMISSION are app-injected per pane; \
            user-provided values are silently overridden.
            """,
        traceEventName: "opencode.config_content.user_override_silenced"
    )

    static let opencodePortMissing = Invariant(
        id: "opencode.port_missing",
        integration: "OpenCode",
        severity: .error,
        description: "An OpenCode pane was started without a configured opencode port.",
        traceEventName: "statusline.opencode.port_missing"
    )
}

struct InvariantViolation: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let invariantID: String
    let integration: String
    let severity: Invariant.Severity
    let description: String
    let timestamp: Date
    let context: [String: String]

    init(invariant: Invariant, context: [String: String], id: UUID = UUID(), timestamp: Date = Date()) {
        self.id = id
        invariantID = invariant.id
        integration = invariant.integration
        severity = invariant.severity
        description = invariant.description
        self.timestamp = timestamp
        self.context = context
    }
}
