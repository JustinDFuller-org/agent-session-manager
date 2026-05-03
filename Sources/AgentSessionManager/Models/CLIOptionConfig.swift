import Foundation

enum CLIOptionType {
    case boolean
    case string(placeholder: String)
}

struct CLIOptionConfig: Identifiable, Codable {
    var id: String
    var label: String
    var description: String
    var isAvailable: Bool
    var isDefaultEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, isAvailable, isDefaultEnabled
    }

    init(id: String, label: String, description: String, isAvailable: Bool, isDefaultEnabled: Bool) {
        self.id = id
        self.label = label
        self.description = description
        self.isAvailable = isAvailable
        self.isDefaultEnabled = isDefaultEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        guard let template = CLIOptionConfig.all.first(where: { $0.id == id }) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Unknown CLI option: \(id)")
        }
        self.id = template.id
        self.label = template.label
        self.description = template.description
        self.isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
        self.isDefaultEnabled = try container.decode(Bool.self, forKey: .isDefaultEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(isAvailable, forKey: .isAvailable)
        try container.encode(isDefaultEnabled, forKey: .isDefaultEnabled)
    }

    var optionType: CLIOptionType {
        switch id {
        case "--continue", "--verbose", "--dangerously-skip-permissions", "--debug", "--no-session-persistence":
            return .boolean
        case "--resume":
            return .string(placeholder: "Session name or ID")
        case "--model":
            return .string(placeholder: "e.g. claude-sonnet-4-6")
        case "--effort":
            return .string(placeholder: "low / medium / high / max")
        case "--permission-mode":
            return .string(placeholder: "plan / auto / acceptEdits / bypassPermissions")
        case "--name":
            return .string(placeholder: "Session display name")
        case "--append-system-prompt":
            return .string(placeholder: "Text to append to system prompt")
        default:
            return .boolean
        }
    }

    static let all: [CLIOptionConfig] = [
        CLIOptionConfig(id: "--continue", label: "Continue", description: "Load the most recent conversation in the current directory", isAvailable: true, isDefaultEnabled: false),
        CLIOptionConfig(id: "--resume", label: "Resume", description: "Resume a specific session by name or ID", isAvailable: true, isDefaultEnabled: false),
        CLIOptionConfig(id: "--verbose", label: "Verbose", description: "Enable verbose logging with full turn-by-turn output", isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(id: "--dangerously-skip-permissions", label: "Skip Permissions", description: "Skip all permission prompts (use with caution)", isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(id: "--debug", label: "Debug", description: "Enable debug mode", isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(id: "--no-session-persistence", label: "No Session Persistence", description: "Disable saving this session to disk", isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(id: "--model", label: "Model", description: "Set the model for this session", isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(id: "--effort", label: "Effort", description: "Set the effort level for this session", isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(id: "--permission-mode", label: "Permission Mode", description: "Begin in a specified permission mode", isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(id: "--name", label: "Session Name", description: "Set a display name for this session", isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(id: "--append-system-prompt", label: "Append System Prompt", description: "Append custom text to the end of the default system prompt", isAvailable: false, isDefaultEnabled: false),
    ]
}
