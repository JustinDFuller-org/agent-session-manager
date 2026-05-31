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
