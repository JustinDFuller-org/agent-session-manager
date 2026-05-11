import Foundation

enum ToolAvailability: Codable {
    case all
    case claudeOnly
    case opencodeOnly
    case claudeOrOpencode
}

enum ChipLabelStyle: String, Codable, CaseIterable {
    case symbolOnly
    case symbolAndLabel
    case labelOnly

    var displayName: String {
        switch self {
        case .symbolOnly: return "Symbol only"
        case .symbolAndLabel: return "Symbol + label"
        case .labelOnly: return "Label only"
        }
    }
}

enum RowAlignment: String, Codable, CaseIterable {
    case leading
    case spaceBetween

    var displayName: String {
        switch self {
        case .leading: return "Left-aligned"
        case .spaceBetween: return "Spread evenly"
        }
    }
}

struct StatusLineItem: Codable, Identifiable, Hashable {
    var id: String
    var label: String
    var sfSymbol: String

    init(id: String, label: String, sfSymbol: String) {
        self.id = id
        self.label = label
        self.sfSymbol = sfSymbol
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        sfSymbol =
            try container.decodeIfPresent(String.self, forKey: .sfSymbol)
            ?? StatusLineConfig.itemMetadata[id]?.symbol ?? "circle"
    }

    var availability: ToolAvailability {
        StatusLineConfig.itemAvailability[id] ?? .all
    }

    func supportedBy(_ cliType: CLIType) -> Bool {
        switch availability {
        case .all: return true
        case .claudeOnly: return cliType == .claude
        case .opencodeOnly: return cliType == .opencode
        case .claudeOrOpencode: return cliType == .claude || cliType == .opencode
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, label, sfSymbol
    }
}

struct StatusLineRow: Codable, Identifiable {
    var id: UUID
    var items: [StatusLineItem]

    init(items: [StatusLineItem] = []) {
        self.id = UUID()
        self.items = items
    }
}

private struct LegacyStatusLineItem: Decodable {
    var id: String
    var label: String
    var sfSymbol: String?
    var isVisible: Bool

    enum CodingKeys: String, CodingKey {
        case id, label, sfSymbol, isVisible
    }
}

struct StatusLineConfig: Codable {
    var rows: [StatusLineRow]
    var chipLabelStyle: ChipLabelStyle
    var rowAlignment: RowAlignment

    static let itemMetadata: [String: (label: String, symbol: String)] = [
        "model": ("Model", "cpu"),
        "worktree": ("Worktree", "folder.badge.gearshape"),
        "cost": ("Cost", "dollarsign.circle"),
        "context": ("Context %", "gauge.with.needle"),
        "effort": ("Effort", "dial.high"),
        "thinking": ("Thinking", "brain"),
        "vimMode": ("Vim Mode", "keyboard"),
        "agentName": ("Agent", "person.crop.circle"),
        "sessionName": ("Session Name", "tag"),
        "worktreeBranch": ("Worktree Branch", "arrow.branch"),
        "gitWorktree": ("Git Worktree", "internaldrive"),
        "linesAdded": ("Lines Added", "plus.square"),
        "linesRemoved": ("Lines Removed", "minus.square"),
        "duration": ("Duration", "clock"),
        "contextRemaining": ("Context Remaining", "gauge.with.needle.fill"),
        "inputTokens": ("Input Tokens", "arrow.down.circle"),
        "outputTokens": ("Output Tokens", "arrow.up.circle"),
        "rate5h": ("5h Rate", "timer"),
        "rate7d": ("7d Rate", "calendar.badge.clock"),
        "rate5hReset": ("5h Resets At", "arrow.clockwise.circle"),
        "rate7dReset": ("7d Resets At", "arrow.clockwise.circle.fill"),
        "version": ("Version", "info.circle"),
        "outputStyle": ("Output Style", "text.alignleft"),
        "exceeds200k": ("Exceeds 200k", "exclamationmark.triangle"),
        "sessionStatus": ("Status", "circle.fill"),
        "openCodeMode": ("Mode", "text.alignleft"),
        "pr": ("PR", "arrow.triangle.pull"),
    ]

    static let itemAvailability: [String: ToolAvailability] = [
        // Agnostic — populated by git queries and process tracking
        "worktree": .all,
        "worktreeBranch": .all,
        "gitWorktree": .all,
        "duration": .all,
        "version": .all,
        "pr": .all,
        // Claude + OpenCode — populated by both via their respective APIs
        "model": .claudeOrOpencode,
        "cost": .claudeOrOpencode,
        "inputTokens": .claudeOrOpencode,
        "outputTokens": .claudeOrOpencode,
        // Claude-only — requires the Claude statusLine hook
        "context": .claudeOnly,
        "effort": .claudeOnly,
        "thinking": .claudeOnly,
        "vimMode": .claudeOnly,
        "agentName": .claudeOnly,
        "sessionName": .claudeOnly,
        "linesAdded": .claudeOnly,
        "linesRemoved": .claudeOnly,
        "contextRemaining": .claudeOnly,
        "rate5h": .claudeOnly,
        "rate7d": .claudeOnly,
        "rate5hReset": .claudeOnly,
        "rate7dReset": .claudeOnly,
        "outputStyle": .claudeOnly,
        "exceeds200k": .claudeOnly,
        // OpenCode-only — populated by OpenCode HTTP API
        "sessionStatus": .opencodeOnly,
        "openCodeMode": .opencodeOnly,
    ]

    static let itemOrder: [String] = [
        "model", "worktree", "cost", "context", "effort", "thinking", "vimMode",
        "agentName", "sessionName", "worktreeBranch", "gitWorktree", "linesAdded",
        "linesRemoved", "duration", "contextRemaining", "inputTokens", "outputTokens",
        "rate5h", "rate7d", "rate5hReset", "rate7dReset", "version", "outputStyle", "exceeds200k",
        "sessionStatus", "openCodeMode",
        "pr",
    ]

    private static let defaultVisible: Set<String> = ["model", "worktree", "cost", "context"]

    static var allItems: [StatusLineItem] {
        itemOrder.compactMap { id in
            guard let meta = itemMetadata[id] else { return nil }
            return StatusLineItem(id: id, label: meta.label, sfSymbol: meta.symbol)
        }
    }

    var usedItemIDs: Set<String> {
        Set(rows.flatMap { $0.items.map(\.id) })
    }

    init() {
        let defaultItems = Self.itemOrder
            .filter { Self.defaultVisible.contains($0) }
            .compactMap { id -> StatusLineItem? in
                guard let meta = Self.itemMetadata[id] else { return nil }
                return StatusLineItem(id: id, label: meta.label, sfSymbol: meta.symbol)
            }
        rows = [StatusLineRow(items: defaultItems)]
        chipLabelStyle = .symbolOnly
        rowAlignment = .leading
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chipLabelStyle = try container.decodeIfPresent(ChipLabelStyle.self, forKey: .chipLabelStyle) ?? .symbolOnly
        rowAlignment = try container.decodeIfPresent(RowAlignment.self, forKey: .rowAlignment) ?? .leading

        if let savedRows = try container.decodeIfPresent([StatusLineRow].self, forKey: .rows) {
            rows = savedRows
        } else if let legacyItems = try container.decodeIfPresent([LegacyStatusLineItem].self, forKey: .items) {
            let visibleItems =
                legacyItems
                .filter(\.isVisible)
                .compactMap { legacy -> StatusLineItem? in
                    guard let meta = StatusLineConfig.itemMetadata[legacy.id] else { return nil }
                    return StatusLineItem(
                        id: legacy.id,
                        label: meta.label,
                        sfSymbol: legacy.sfSymbol ?? meta.symbol
                    )
                }
            rows = [StatusLineRow(items: visibleItems)]
        } else {
            let defaults = StatusLineConfig()
            rows = defaults.rows
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rows, forKey: .rows)
        try container.encode(chipLabelStyle, forKey: .chipLabelStyle)
        try container.encode(rowAlignment, forKey: .rowAlignment)
    }

    enum CodingKeys: String, CodingKey {
        case rows, chipLabelStyle, rowAlignment
        case items
    }
}

struct StatusCheck: Codable, Identifiable {
    let name: String
    let status: String
    let conclusion: String?
    let detailsUrl: String?

    var id: String { name }

    var isFailing: Bool {
        let failedConclusions: Set<String> = ["FAILURE", "TIMED_OUT", "STARTUP_FAILURE", "ACTION_REQUIRED"]
        return failedConclusions.contains(conclusion?.uppercased() ?? "")
    }

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case conclusion
        case detailsUrl
    }
}

enum BuildStatus: Equatable {
    case success
    case running
    case failed
    case cancelled
    case unknown
}

struct PullRequest: Codable, Identifiable {
    let number: Int
    let title: String
    let state: String
    let url: String
    var isDraft: Bool?
    var statusCheckRollup: [StatusCheck]?
    var unresolvedCommentCount: Int?
    var commitStatusState: String?

    var id: Int { number }

    var displayState: String {
        if isDraft == true { return "draft" }
        switch state.lowercased() {
        case "open": return "open"
        case "merged": return "merged"
        case "closed": return "closed"
        default: return state.lowercased()
        }
    }

    var buildStatus: BuildStatus {
        if let checks = statusCheckRollup, !checks.isEmpty {
            let failedConclusions: Set<String> = ["FAILURE", "TIMED_OUT", "STARTUP_FAILURE", "ACTION_REQUIRED"]
            if checks.contains(where: { failedConclusions.contains($0.conclusion?.uppercased() ?? "") }) {
                return .failed
            }
            if checks.contains(where: { $0.conclusion?.uppercased() == "CANCELLED" }) {
                return .cancelled
            }
            let runningStatuses: Set<String> = ["IN_PROGRESS", "QUEUED", "WAITING", "REQUESTED", "PENDING"]
            if checks.contains(where: { runningStatuses.contains($0.status.uppercased()) }) {
                return .running
            }
            let passConclusions: Set<String> = ["SUCCESS", "NEUTRAL", "SKIPPED"]
            if checks.allSatisfy({ passConclusions.contains($0.conclusion?.uppercased() ?? "") }) {
                return .success
            }
        }
        guard let apiState = commitStatusState else { return .unknown }
        switch apiState.uppercased() {
        case "SUCCESS": return .success
        case "FAILURE", "ERROR": return .failed
        case "PENDING": return .running
        default: return .unknown
        }
    }

    var stateIconName: String {
        if isDraft == true { return "pencil.line" }
        switch state.lowercased() {
        case "open": return "arrow.triangle.pull"
        case "merged": return "arrow.triangle.merge"
        case "closed": return "xmark.circle"
        default: return "arrow.triangle.pull"
        }
    }

    var failingChecks: [StatusCheck] {
        statusCheckRollup?.filter { $0.isFailing } ?? []
    }

    enum CodingKeys: String, CodingKey {
        case number
        case title
        case state
        case url
        case isDraft
        case statusCheckRollup
    }
}

struct StatusLineData: Codable {
    struct Model: Codable {
        let id: String?
        let displayName: String?
        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    struct Cost: Codable {
        let totalCostUsd: Double?
        let totalDurationMs: Double?
        let totalLinesAdded: Int?
        let totalLinesRemoved: Int?
        enum CodingKeys: String, CodingKey {
            case totalCostUsd = "total_cost_usd"
            case totalDurationMs = "total_duration_ms"
            case totalLinesAdded = "total_lines_added"
            case totalLinesRemoved = "total_lines_removed"
        }
    }

    struct ContextWindow: Codable {
        let usedPercentage: Int?
        let remainingPercentage: Int?
        let totalInputTokens: Int?
        let totalOutputTokens: Int?
        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case remainingPercentage = "remaining_percentage"
            case totalInputTokens = "total_input_tokens"
            case totalOutputTokens = "total_output_tokens"
        }
    }

    struct RateLimit: Codable {
        let usedPercentage: Double?
        let resetsAt: Int?
        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case resetsAt = "resets_at"
        }
    }

    struct RateLimits: Codable {
        let fiveHour: RateLimit?
        let sevenDay: RateLimit?
        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    struct Workspace: Codable {
        let gitWorktree: String?
        enum CodingKeys: String, CodingKey {
            case gitWorktree = "git_worktree"
        }
    }

    struct Worktree: Codable {
        let name: String?
        let branch: String?
    }

    struct Effort: Codable {
        let level: String?
    }

    struct Thinking: Codable {
        let enabled: Bool?
    }

    struct Agent: Codable {
        let name: String?
    }

    struct OutputStyle: Codable {
        let name: String?
        enum CodingKeys: String, CodingKey { case name }
    }

    struct Vim: Codable {
        let mode: String?
    }

    struct SessionStatus: Codable {
        let state: String?
        enum CodingKeys: String, CodingKey { case state }
    }

    let model: Model?
    let cost: Cost?
    let contextWindow: ContextWindow?
    let rateLimits: RateLimits?
    let worktree: Worktree?
    let workspace: Workspace?
    let effort: Effort?
    let thinking: Thinking?
    let agent: Agent?
    let outputStyle: OutputStyle?
    let vim: Vim?
    let sessionName: String?
    let version: String?
    let exceeds200kTokens: Bool?
    let sessionStatus: SessionStatus?
    let openCodeMode: String?
    var pr: PullRequest?

    enum CodingKeys: String, CodingKey {
        case model
        case cost
        case contextWindow = "context_window"
        case rateLimits = "rate_limits"
        case worktree
        case workspace
        case effort
        case thinking
        case agent
        case outputStyle = "output_style"
        case vim
        case sessionName = "session_name"
        case version
        case exceeds200kTokens = "exceeds_200k_tokens"
        case sessionStatus = "session_status"
        case openCodeMode = "open_code_mode"
        case pr
    }
}
