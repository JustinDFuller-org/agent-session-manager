import Foundation

enum StatusFactOwner: String, Codable {
    case app
    case harness
    case merged
}

enum MissingStatusFactBehavior: String, Codable {
    case pending
    case unsupported
}

struct StatusFactCapability: Codable, Equatable {
    let owner: StatusFactOwner
    let supportedHarnesses: Set<Harness>
    let missingBehavior: MissingStatusFactBehavior

    func supports(_ harness: Harness) -> Bool {
        supportedHarnesses.contains(harness)
    }
}

enum FactLabelStyle: String, Codable, CaseIterable {
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

    var capability: StatusFactCapability {
        StatusLineConfig.itemCapabilities[id] ?? StatusLineConfig.appCapability
    }

    func supportedBy(_ harness: Harness) -> Bool {
        capability.supports(harness)
    }

    enum CodingKeys: String, CodingKey {
        case id, label, sfSymbol
    }
}

struct StatusLineRow: Codable, Identifiable, Equatable {
    var id: UUID
    var items: [StatusLineItem]

    init(items: [StatusLineItem] = []) {
        self.id = UUID()
        self.items = items
    }
}

enum CustomFieldTint: String, Codable {
    case normal
    case good
    case warning
    case critical
}

/// The render contract a custom field's command emits on stdout. Plain text (the "echo hello" path)
/// decodes to this with only `text` set; a script opts into a progress bar or state color by
/// printing this shape as JSON instead.
struct CustomFieldRenderValue: Codable, Equatable {
    var text: String?
    var percent: Double?
    var tint: CustomFieldTint?
    var icon: String?

    var isEmpty: Bool { text == nil && percent == nil && tint == nil && icon == nil }
}

/// An engineer-defined status line field backed by a shell command. See `CustomFieldRunner` for
/// execution, context-building, and output parsing.
struct CustomStatusLineField: Codable, Identifiable, Equatable {
    static let minimumRefreshIntervalSeconds = 5
    static let defaultRefreshIntervalSeconds = 15
    static let defaultTimeoutSeconds = 10

    var id: String
    var label: String
    var sfSymbol: String
    var command: String
    var refreshIntervalSeconds: Int
    var timeoutSeconds: Int

    init(
        id: String = "custom:\(UUID().uuidString)",
        label: String,
        sfSymbol: String = "terminal",
        command: String,
        refreshIntervalSeconds: Int = defaultRefreshIntervalSeconds,
        timeoutSeconds: Int = defaultTimeoutSeconds
    ) {
        self.id = id
        self.label = label
        self.sfSymbol = sfSymbol
        self.command = command
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.timeoutSeconds = timeoutSeconds
    }

    var effectiveRefreshIntervalSeconds: Int {
        max(Self.minimumRefreshIntervalSeconds, refreshIntervalSeconds)
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

struct StatusLineConfig: Codable, Equatable {
    var rows: [StatusLineRow]
    var factLabelStyle: FactLabelStyle
    var rowAlignment: RowAlignment
    var showPercentagesAsText: Bool
    var customFields: [CustomStatusLineField]

    static let itemMetadata: [String: (label: String, symbol: String)] = [
        "model": ("Model", "cpu"),
        "worktree": ("Worktree", "folder.badge.gearshape"),
        "cost": ("Cost", "dollarsign.circle"),
        "context": ("Context Used", "gauge.with.needle"),
        "effort": ("Effort", "dial.high"),
        "thinking": ("Thinking", "brain"),
        "vimMode": ("Vim Mode", "keyboard"),
        "agentName": ("Agent", "person.crop.circle"),
        "sessionName": ("Session Name", "tag"),
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
        "pr": ("PR", "arrow.triangle.pull"),
        "profileName": ("Profile", "person.crop.rectangle"),
        "repo": ("Repository", "chevron.left.forwardslash.chevron.right"),
        "contextSize": ("Context Size", "ruler"),
        "cacheRead": ("Cache Read", "arrow.down.doc"),
        "cacheCreation": ("Cache Write", "arrow.up.doc"),
        "apiDuration": ("API Duration", "clock.arrow.2.circlepath"),
    ]

    static let allHarnesses: Set<Harness> = [.claude, .codex, .cursor, .opencode]
    static let appCapability = StatusFactCapability(
        owner: .app, supportedHarnesses: allHarnesses, missingBehavior: .pending)
    static let mergedCapability = StatusFactCapability(
        owner: .merged, supportedHarnesses: allHarnesses, missingBehavior: .pending)
    static let claudeCapability = StatusFactCapability(
        owner: .harness, supportedHarnesses: [.claude], missingBehavior: .unsupported)
    static let claudeCodexCapability = StatusFactCapability(
        owner: .harness, supportedHarnesses: [.claude, .codex], missingBehavior: .pending)
    static let modelCapability = StatusFactCapability(
        owner: .merged, supportedHarnesses: allHarnesses, missingBehavior: .pending)
    static let claudeOpencodeCapability = StatusFactCapability(
        owner: .harness, supportedHarnesses: [.claude, .opencode], missingBehavior: .pending)
    static let inputOutputTokenCapability = StatusFactCapability(
        owner: .harness, supportedHarnesses: [.claude, .codex, .opencode], missingBehavior: .pending)

    static let itemCapabilities: [String: StatusFactCapability] = [
        "worktree": appCapability,
        "duration": appCapability,
        "version": mergedCapability,
        "pr": appCapability,
        "linesAdded": appCapability,
        "linesRemoved": appCapability,
        "profileName": appCapability,
        "model": modelCapability,
        "cost": claudeOpencodeCapability,
        "inputTokens": inputOutputTokenCapability,
        "outputTokens": inputOutputTokenCapability,
        "context": claudeCodexCapability,
        "contextRemaining": claudeCodexCapability,
        "rate5h": claudeCodexCapability,
        "rate7d": claudeCodexCapability,
        "rate5hReset": claudeCodexCapability,
        "rate7dReset": claudeCodexCapability,
        "effort": claudeCapability,
        "thinking": claudeCapability,
        "vimMode": claudeCapability,
        "agentName": claudeCapability,
        "sessionName": claudeOpencodeCapability,
        "outputStyle": claudeCapability,
        "exceeds200k": claudeCapability,
        "repo": appCapability,
        "contextSize": claudeCapability,
        "cacheRead": claudeCapability,
        "cacheCreation": claudeCapability,
        "apiDuration": claudeCapability,
    ]

    static let itemAvailability: [String: StatusFactCapability] = itemCapabilities

    static let itemOrder: [String] = [
        "model", "worktree", "cost", "context", "effort", "thinking", "vimMode",
        "agentName", "sessionName", "linesAdded",
        "linesRemoved", "duration", "contextRemaining", "inputTokens", "outputTokens",
        "rate5h", "rate7d", "rate5hReset", "rate7dReset", "version", "outputStyle", "exceeds200k",
        "pr", "profileName",
        "repo", "contextSize", "cacheRead", "cacheCreation", "apiDuration",
    ]

    private static let defaultVisible: Set<String> = ["model", "worktree", "cost", "context"]

    static var allItems: [StatusLineItem] {
        itemOrder.compactMap { id in
            guard let meta = itemMetadata[id] else { return nil }
            return StatusLineItem(id: id, label: meta.label, sfSymbol: meta.symbol)
        }
    }

    /// Built-in catalog plus this config's own custom fields — the full set eligible for the Add Item picker.
    func availableItems() -> [StatusLineItem] {
        Self.allItems + customFields.map { StatusLineItem(id: $0.id, label: $0.label, sfSymbol: $0.sfSymbol) }
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
        factLabelStyle = .symbolAndLabel
        rowAlignment = .spaceBetween
        showPercentagesAsText = false
        customFields = []
    }

    static func wizardDefault() -> StatusLineConfig {
        func item(_ id: String) -> StatusLineItem {
            let meta = itemMetadata[id]!
            return StatusLineItem(id: id, label: meta.label, sfSymbol: meta.symbol)
        }
        var config = StatusLineConfig()
        config.factLabelStyle = .symbolAndLabel
        config.rowAlignment = .spaceBetween
        config.rows = [
            StatusLineRow(items: [item("pr"), item("profileName"), item("model")]),
            StatusLineRow(
                items: [item("context"), item("contextRemaining"), item("inputTokens"), item("outputTokens")]),
            StatusLineRow(items: [item("worktree"), item("linesAdded"), item("linesRemoved")]),
        ]
        return config
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        factLabelStyle =
            try container.decodeIfPresent(FactLabelStyle.self, forKey: .factLabelStyle) ?? .symbolAndLabel
        rowAlignment = try container.decodeIfPresent(RowAlignment.self, forKey: .rowAlignment) ?? .spaceBetween
        showPercentagesAsText = try container.decodeIfPresent(Bool.self, forKey: .showPercentagesAsText) ?? false
        customFields = try container.decodeIfPresent([CustomStatusLineField].self, forKey: .customFields) ?? []

        if let savedRows = try container.decodeIfPresent([StatusLineRow].self, forKey: .rows) {
            rows = savedRows.enumerated().map { rowIndex, row in
                var mutableRow = row
                let rowHasWorktree = row.items.contains { $0.id == "worktree" }
                mutableRow.items = row.items.enumerated().compactMap { itemIndex, item in
                    if item.id == "gitWorktree" {
                        TracingService.shared.record(
                            "statusline.migration.gitworktree_dropped",
                            attributes: ["row_index": "\(rowIndex)", "position": "\(itemIndex)"])
                        return nil
                    }
                    if item.id == "worktreeBranch" {
                        let substituted = !rowHasWorktree
                        TracingService.shared.record(
                            "statusline.migration.worktreebranch_merged",
                            attributes: [
                                "row_index": "\(rowIndex)",
                                "position": "\(itemIndex)",
                                "substituted": substituted ? "true" : "false",
                            ])
                        if substituted {
                            let meta = StatusLineConfig.itemMetadata["worktree"]!
                            return StatusLineItem(id: "worktree", label: meta.label, sfSymbol: meta.symbol)
                        }
                        return nil
                    }
                    if let meta = StatusLineConfig.itemMetadata[item.id] {
                        return StatusLineItem(id: item.id, label: meta.label, sfSymbol: meta.symbol)
                    }
                    return item
                }
                return mutableRow
            }
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
        try container.encode(factLabelStyle, forKey: .factLabelStyle)
        try container.encode(rowAlignment, forKey: .rowAlignment)
        try container.encode(showPercentagesAsText, forKey: .showPercentagesAsText)
        try container.encode(customFields, forKey: .customFields)
    }

    enum CodingKeys: String, CodingKey {
        case rows, factLabelStyle, rowAlignment, showPercentagesAsText, customFields
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
    var mergeable: String?
    var reviewDecision: String?

    var reviewStateLabel: String? {
        if isDraft == true { return "draft" }
        guard let decision = reviewDecision else { return nil }
        switch decision {
        case "APPROVED": return "approved"
        case "CHANGES_REQUESTED": return "changes requested"
        case "REVIEW_REQUIRED": return "pending"
        default: return nil
        }
    }

    var id: Int { number }

    var hasMergeConflicts: Bool {
        mergeable?.uppercased() == "CONFLICTING"
    }

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
        case mergeable
    }
}

struct StatusLineData: Codable {
    struct Repo: Codable {
        let host: String
        let owner: String
        let name: String
    }

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
        let totalApiDurationMs: Double?
        enum CodingKeys: String, CodingKey {
            case totalCostUsd = "total_cost_usd"
            case totalDurationMs = "total_duration_ms"
            case totalLinesAdded = "total_lines_added"
            case totalLinesRemoved = "total_lines_removed"
            case totalApiDurationMs = "total_api_duration_ms"
        }

        init(
            totalCostUsd: Double?,
            totalDurationMs: Double?,
            totalLinesAdded: Int?,
            totalLinesRemoved: Int?,
            totalApiDurationMs: Double? = nil
        ) {
            self.totalCostUsd = totalCostUsd
            self.totalDurationMs = totalDurationMs
            self.totalLinesAdded = totalLinesAdded
            self.totalLinesRemoved = totalLinesRemoved
            self.totalApiDurationMs = totalApiDurationMs
        }
    }

    struct ContextWindow: Codable {
        struct CurrentUsage: Codable {
            let inputTokens: Int?
            let outputTokens: Int?
            let cacheCreationInputTokens: Int?
            let cacheReadInputTokens: Int?
            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
        }

        let usedPercentage: Int?
        let remainingPercentage: Int?
        let totalInputTokens: Int?
        let totalOutputTokens: Int?
        let contextWindowSize: Int?
        let currentUsage: CurrentUsage?

        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case remainingPercentage = "remaining_percentage"
            case totalInputTokens = "total_input_tokens"
            case totalOutputTokens = "total_output_tokens"
            case contextWindowSize = "context_window_size"
            case currentUsage = "current_usage"
        }

        init(
            usedPercentage: Int?,
            remainingPercentage: Int?,
            totalInputTokens: Int?,
            totalOutputTokens: Int?,
            contextWindowSize: Int? = nil,
            currentUsage: CurrentUsage? = nil
        ) {
            self.usedPercentage = usedPercentage
            self.remainingPercentage = remainingPercentage
            self.totalInputTokens = totalInputTokens
            self.totalOutputTokens = totalOutputTokens
            self.contextWindowSize = contextWindowSize
            self.currentUsage = currentUsage
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            usedPercentage = Self.flexInt(container, key: .usedPercentage)
            remainingPercentage = Self.flexInt(container, key: .remainingPercentage)
            totalInputTokens = Self.flexInt(container, key: .totalInputTokens)
            totalOutputTokens = Self.flexInt(container, key: .totalOutputTokens)
            contextWindowSize = Self.flexInt(container, key: .contextWindowSize)
            currentUsage = try? container.decodeIfPresent(CurrentUsage.self, forKey: .currentUsage)
        }

        private static func flexInt(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
            if let decoded = try? container.decodeIfPresent(Int.self, forKey: key) { return decoded }
            if let decoded = try? container.decodeIfPresent(Double.self, forKey: key) { return Int(decoded) }
            return nil
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

        var factText: String {
            guard let name else { return "—" }
            if let branch { return "\(name) • \(branch)" }
            return name
        }
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
    }

    var model: Model?
    var cost: Cost?
    var contextWindow: ContextWindow?
    var rateLimits: RateLimits?
    var worktree: Worktree?
    let workspace: Workspace?
    var effort: Effort?
    var thinking: Thinking?
    var agent: Agent?
    var outputStyle: OutputStyle?
    var vim: Vim?
    var sessionName: String?
    var version: String?
    var exceeds200kTokens: Bool?
    // Owned by PRTrackingCoordinator (gh GraphQL). Not decoded from Claude's statusLine payload,
    // which carries only number/url/review_state — never title/state (non-optional on PullRequest).
    var pr: PullRequest?
    var sessionStatus: SessionStatus?
    var repo: Repo?
    // Owned by StatusLineMonitor's custom-field scheduler. Not decoded from any harness's JSON —
    // excluding it from CodingKeys means nothing external can spoof a resolved custom value.
    var customFields: [String: CustomFieldRenderValue]?

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
        case repo
    }

    static func empty(pr: PullRequest? = nil) -> StatusLineData {
        StatusLineData(
            model: nil, cost: nil, contextWindow: nil, rateLimits: nil,
            worktree: nil, workspace: nil, effort: nil, thinking: nil,
            agent: nil, outputStyle: nil, vim: nil,
            sessionName: nil, version: nil, exceeds200kTokens: nil,
            pr: pr, sessionStatus: nil, repo: nil
        )
    }
}
