import Foundation

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

struct StatusLineItem: Codable, Identifiable {
    var id: String
    var label: String
    var sfSymbol: String
    var isVisible: Bool

    init(id: String, label: String, sfSymbol: String, isVisible: Bool) {
        self.id = id
        self.label = label
        self.sfSymbol = sfSymbol
        self.isVisible = isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        sfSymbol = try container.decodeIfPresent(String.self, forKey: .sfSymbol)
            ?? StatusLineConfig.itemMetadata[id]?.symbol ?? "circle"
    }

    enum CodingKeys: String, CodingKey {
        case id, label, sfSymbol, isVisible
    }
}

struct StatusLineConfig: Codable {
    var items: [StatusLineItem]
    var chipLabelStyle: ChipLabelStyle
    var rowAlignment: RowAlignment

    static let itemMetadata: [String: (label: String, symbol: String)] = [
        "model":            ("Model",             "cpu"),
        "worktree":         ("Worktree",          "folder.badge.gearshape"),
        "cost":             ("Cost",              "dollarsign.circle"),
        "context":          ("Context %",         "gauge.with.needle"),
        "effort":           ("Effort",            "dial.high"),
        "thinking":         ("Thinking",          "brain"),
        "vimMode":          ("Vim Mode",          "keyboard"),
        "agentName":        ("Agent",             "person.crop.circle"),
        "sessionName":      ("Session Name",      "tag"),
        "worktreeBranch":   ("Worktree Branch",   "arrow.branch"),
        "gitWorktree":      ("Git Worktree",      "internaldrive"),
        "linesAdded":       ("Lines Added",       "plus.square"),
        "linesRemoved":     ("Lines Removed",     "minus.square"),
        "duration":         ("Duration",          "clock"),
        "contextRemaining": ("Context Remaining", "gauge.with.needle.fill"),
        "inputTokens":      ("Input Tokens",      "arrow.down.circle"),
        "outputTokens":     ("Output Tokens",     "arrow.up.circle"),
        "rate5h":           ("5h Rate",           "timer"),
        "rate7d":           ("7d Rate",           "calendar.badge.clock"),
        "rate5hReset":      ("5h Resets At",      "arrow.clockwise.circle"),
        "rate7dReset":      ("7d Resets At",      "arrow.clockwise.circle.fill"),
        "version":          ("Version",           "info.circle"),
        "outputStyle":      ("Output Style",      "text.alignleft"),
        "exceeds200k":      ("Exceeds 200k",      "exclamationmark.triangle"),
    ]

    private static let itemOrder: [String] = [
        "model", "worktree", "cost", "context", "effort", "thinking", "vimMode",
        "agentName", "sessionName", "worktreeBranch", "gitWorktree", "linesAdded",
        "linesRemoved", "duration", "contextRemaining", "inputTokens", "outputTokens",
        "rate5h", "rate7d", "rate5hReset", "rate7dReset", "version", "outputStyle", "exceeds200k",
    ]

    private static let defaultVisible: Set<String> = ["model", "worktree", "cost", "context"]

    init() {
        items = Self.itemOrder.compactMap { id in
            guard let meta = Self.itemMetadata[id] else { return nil }
            return StatusLineItem(id: id, label: meta.label, sfSymbol: meta.symbol, isVisible: Self.defaultVisible.contains(id))
        }
        chipLabelStyle = .symbolOnly
        rowAlignment = .leading
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([StatusLineItem].self, forKey: .items)
        chipLabelStyle = try container.decodeIfPresent(ChipLabelStyle.self, forKey: .chipLabelStyle) ?? .symbolOnly
        rowAlignment = try container.decodeIfPresent(RowAlignment.self, forKey: .rowAlignment) ?? .leading
    }

    enum CodingKeys: String, CodingKey {
        case items, chipLabelStyle, rowAlignment
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
    }
}
