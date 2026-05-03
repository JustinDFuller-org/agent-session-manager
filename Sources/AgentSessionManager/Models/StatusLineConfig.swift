import Foundation

struct StatusLineItem: Codable, Identifiable {
    var id: String
    var label: String
    var isVisible: Bool
}

struct StatusLineConfig: Codable {
    var items: [StatusLineItem]

    init() {
        items = [
            StatusLineItem(id: "model",           label: "Model",              isVisible: true),
            StatusLineItem(id: "worktree",         label: "Worktree",           isVisible: true),
            StatusLineItem(id: "cost",             label: "Cost",               isVisible: true),
            StatusLineItem(id: "context",          label: "Context %",          isVisible: true),
            StatusLineItem(id: "effort",           label: "Effort",             isVisible: false),
            StatusLineItem(id: "thinking",         label: "Thinking",           isVisible: false),
            StatusLineItem(id: "vimMode",          label: "Vim Mode",           isVisible: false),
            StatusLineItem(id: "agentName",        label: "Agent",              isVisible: false),
            StatusLineItem(id: "sessionName",      label: "Session Name",       isVisible: false),
            StatusLineItem(id: "worktreeBranch",   label: "Worktree Branch",    isVisible: false),
            StatusLineItem(id: "gitWorktree",      label: "Git Worktree",       isVisible: false),
            StatusLineItem(id: "linesAdded",       label: "Lines Added",        isVisible: false),
            StatusLineItem(id: "linesRemoved",     label: "Lines Removed",      isVisible: false),
            StatusLineItem(id: "duration",         label: "Duration",           isVisible: false),
            StatusLineItem(id: "contextRemaining", label: "Context Remaining",  isVisible: false),
            StatusLineItem(id: "inputTokens",      label: "Input Tokens",       isVisible: false),
            StatusLineItem(id: "outputTokens",     label: "Output Tokens",      isVisible: false),
            StatusLineItem(id: "rate5h",           label: "5h Rate",            isVisible: false),
            StatusLineItem(id: "rate7d",           label: "7d Rate",            isVisible: false),
            StatusLineItem(id: "rate5hReset",      label: "5h Resets At",       isVisible: false),
            StatusLineItem(id: "rate7dReset",      label: "7d Resets At",       isVisible: false),
            StatusLineItem(id: "version",          label: "Version",            isVisible: false),
            StatusLineItem(id: "outputStyle",      label: "Output Style",       isVisible: false),
            StatusLineItem(id: "exceeds200k",      label: "Exceeds 200k",       isVisible: false),
        ]
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
