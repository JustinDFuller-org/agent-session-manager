import Foundation

enum AgentControlInjectionPolicy: String, Codable, CaseIterable, Sendable {
    case always
    case never
    case askOn = "ask_on"
    case askOff = "ask_off"

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .never: return "Never"
        case .askOn: return "Ask (on by default)"
        case .askOff: return "Ask (off by default)"
        }
    }

    var description: String {
        switch self {
        case .always: return "Make Agent Session Manager control available in every new or restarted pane."
        case .never: return "Keep Agent Session Manager control unavailable in every new or restarted pane."
        case .askOn: return "Show the control enabled by default when creating or refreshing a pane."
        case .askOff: return "Show the control disabled by default when creating or refreshing a pane."
        }
    }

    var isAskPolicy: Bool {
        self == .askOn || self == .askOff
    }

    func resolve(persistedDecision: Bool?) -> Bool {
        switch self {
        case .always: return true
        case .never: return false
        case .askOn: return persistedDecision ?? true
        case .askOff: return persistedDecision ?? false
        }
    }
}

enum AgentControlScope: String, Codable, CaseIterable, Sendable {
    case pane
    case tab
    case global

    var displayName: String {
        rawValue.capitalized
    }

    var description: String {
        switch self {
        case .pane: return "The agent can access only its own pane."
        case .tab: return "The agent can access every pane in its tab."
        case .global: return "The agent can access the entire app."
        }
    }
}

struct AgentControlSettings: Codable, Equatable {
    var injectionPolicy: AgentControlInjectionPolicy = .askOn
    var scope: AgentControlScope = .global

    init(
        injectionPolicy: AgentControlInjectionPolicy = .askOn,
        scope: AgentControlScope = .global
    ) {
        self.injectionPolicy = injectionPolicy
        self.scope = scope
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        injectionPolicy =
            (try? container.decodeIfPresent(AgentControlInjectionPolicy.self, forKey: .injectionPolicy)) ?? .askOn
        scope = (try? container.decodeIfPresent(AgentControlScope.self, forKey: .scope)) ?? .global
    }
}
