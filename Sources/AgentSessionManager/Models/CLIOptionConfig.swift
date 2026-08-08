import Foundation

enum CLIOptionType {
    case boolean
    case string(placeholder: String)
    case optionalString(placeholder: String)

    var placeholder: String? {
        switch self {
        case .boolean: return nil
        case .string(let placeholder), .optionalString(let placeholder): return placeholder
        }
    }
}

struct CLIOptionConfig: Identifiable, Codable {
    var id: String
    var label: String
    var description: String
    var isAvailable: Bool
    var isDefaultEnabled: Bool
    var isUserAdded: Bool
    var customIsStringType: Bool
    var isOptionalStringType: Bool
    var isStringType: Bool
    /// Candidate values offered when selecting this flag, defined at harness scope in Settings → Tools.
    var presetValues: [String]
    /// Whether this flag's CLI syntax accepts multiple space-separated values behind one flag
    /// (e.g. `--mcp-config 'a.json' 'b.json'`), rather than a single value. User-configurable per
    /// flag in Settings → Tools; the user is responsible for only enabling this on flags whose CLI
    /// is actually variadic.
    var allowsMultipleValues: Bool

    enum CodingKeys: String, CodingKey {
        case id, isAvailable, isDefaultEnabled, isUserAdded, customIsStringType, isOptionalStringType, isStringType,
            presetValues, allowsMultipleValues
    }

    /// When set on a `JSONDecoder`'s `userInfo`, harness-aware decode resolves colliding
    /// flag IDs (e.g. `--agent`, `--continue`, `--model`) to the matching template from
    /// the supplied harness's catalog before falling back to a combined search across all
    /// catalogs. Without this key the decoder preserves legacy behavior: combined search
    /// with the Claude catalog searched first.
    static let harnessUserInfoKey =
        CodingUserInfoKey(rawValue: "io.opencode.clioption.harness")!

    static func catalog(for harness: Harness) -> [CLIOptionConfig] {
        switch harness {
        case .claude: return all
        case .codex: return codexAll
        case .cursor: return cursorAll
        case .opencode: return opencodeAll
        case .omp: return ompAll
        case .shell: return []
        }
    }

    init(
        id: String, label: String, description: String, isAvailable: Bool, isDefaultEnabled: Bool,
        isUserAdded: Bool = false, customIsStringType: Bool = false, isOptionalStringType: Bool = false,
        isStringType: Bool = false, presetValues: [String] = [], allowsMultipleValues: Bool = false
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.isAvailable = isAvailable
        self.isDefaultEnabled = isDefaultEnabled
        self.isUserAdded = isUserAdded
        self.customIsStringType = customIsStringType
        self.isOptionalStringType = isOptionalStringType
        self.isStringType = isStringType
        self.presetValues = presetValues
        self.allowsMultipleValues = allowsMultipleValues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let isUserAdded = (try? container.decodeIfPresent(Bool.self, forKey: .isUserAdded)) ?? false

        if isUserAdded {
            let id = try container.decode(String.self, forKey: .id)
            self.id = id
            self.label = id
            self.description = "User-defined option"
            self.isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
            self.isDefaultEnabled = try container.decode(Bool.self, forKey: .isDefaultEnabled)
            self.isUserAdded = true
            self.customIsStringType = (try? container.decodeIfPresent(Bool.self, forKey: .customIsStringType)) ?? false
            self.isOptionalStringType = false
            self.isStringType = false
            self.presetValues = (try? container.decodeIfPresent([String].self, forKey: .presetValues)) ?? []
            self.allowsMultipleValues = false
        } else {
            let id = try container.decode(String.self, forKey: .id)
            let preferredCatalog: [CLIOptionConfig]
            if let harness = decoder.userInfo[CLIOptionConfig.harnessUserInfoKey] as? Harness {
                preferredCatalog = CLIOptionConfig.catalog(for: harness)
            } else {
                preferredCatalog = []
            }
            let allTemplates =
                preferredCatalog
                + CLIOptionConfig.all + CLIOptionConfig.codexAll + CLIOptionConfig.cursorAll
                + CLIOptionConfig.opencodeAll + CLIOptionConfig.ompAll
            guard let template = allTemplates.first(where: { $0.id == id }) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .id, in: container, debugDescription: "Unknown CLI option: \(id)")
            }
            self.id = template.id
            self.label = template.label
            self.description = template.description
            self.isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
            self.isDefaultEnabled = try container.decode(Bool.self, forKey: .isDefaultEnabled)
            self.isUserAdded = false
            self.customIsStringType = false
            self.isOptionalStringType = template.isOptionalStringType
            self.isStringType = template.isStringType
            self.presetValues = (try? container.decodeIfPresent([String].self, forKey: .presetValues)) ?? []
            self.allowsMultipleValues =
                (try? container.decodeIfPresent(Bool.self, forKey: .allowsMultipleValues))
                ?? template.allowsMultipleValues
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(isAvailable, forKey: .isAvailable)
        try container.encode(isDefaultEnabled, forKey: .isDefaultEnabled)
        if isUserAdded {
            try container.encode(true, forKey: .isUserAdded)
            try container.encode(customIsStringType, forKey: .customIsStringType)
        } else {
            try container.encode(isOptionalStringType, forKey: .isOptionalStringType)
            if isStringType {
                try container.encode(true, forKey: .isStringType)
            }
            try container.encode(allowsMultipleValues, forKey: .allowsMultipleValues)
        }
        if !presetValues.isEmpty {
            try container.encode(presetValues, forKey: .presetValues)
        }
    }

    var optionType: CLIOptionType {
        if isUserAdded {
            return customIsStringType ? .string(placeholder: "Value") : .boolean
        }
        if isOptionalStringType {
            return .optionalString(placeholder: "Session ID or prefix (empty opens picker)")
        }
        if isStringType {
            return .string(placeholder: "Value")
        }
        switch id {
        // Boolean flags
        case "--allow-dangerously-skip-permissions",
            "--bare",
            "--chrome",
            "--continue",
            "--dangerously-skip-permissions",
            "--disable-slash-commands",
            "--ide",
            "--no-chrome",
            "--no-session-persistence",
            "--strict-mcp-config",
            "--verbose":
            return .boolean
        // Codex-specific boolean flags (not in Claude's all list)
        case "--dangerously-bypass-approvals-and-sandbox",
            "--no-alt-screen",
            "--oss",
            "--search":
            return .boolean
        // Cursor-specific boolean flags
        case "--approve-mcps",
            "--force",
            "--list-models",
            "--plan",
            "--stream-partial-output",
            "--trust",
            "--yolo":
            return .boolean
        // Cursor-specific string flags
        case "--api-key":
            return .string(placeholder: "API key (or set CURSOR_API_KEY env var)")
        case "--header":
            return .string(placeholder: "Name: Value")
        case "--mode":
            return .string(placeholder: "plan / ask (default: agent)")
        case "--workspace":
            return .string(placeholder: "Path to workspace directory")
        // Codex-specific string flags (not in Claude's all list)
        case "--ask-for-approval":
            return .string(placeholder: "untrusted / on-request / never")
        case "--config":
            return .string(placeholder: "key=value")
        case "--disable":
            return .string(placeholder: "feature name")
        case "--enable":
            return .string(placeholder: "feature name")
        case "--image":
            return .string(placeholder: "path/to/image")
        case "--profile":
            return .string(placeholder: "profile name")
        case "--sandbox":
            return .string(placeholder: "read-only / workspace-write / danger-full-access")
        // OpenCode-specific string flags (not in Claude's all list)
        case "--cors":
            return .string(placeholder: "Origin(s) allowed for CORS")
        case "--hostname":
            return .string(placeholder: "Local server hostname")
        case "--mdns-domain":
            return .string(placeholder: "Custom mDNS domain")
        case "--port":
            return .string(placeholder: "Local server port")
        case "--prompt":
            return .string(placeholder: "Initial prompt")
        case "--session":
            return .string(placeholder: "Session ID to continue")
        // String flags
        case "--add-dir":
            return .string(placeholder: "Path to additional working directory")
        case "--agent":
            return .string(placeholder: "Agent name")
        case "--agents":
            return .string(placeholder: "{\"name\":{\"description\":\"...\",\"prompt\":\"...\"}}")
        case "--allowedTools":
            return .string(placeholder: "\"Bash(git log *)\" \"Read\"")
        case "--append-system-prompt":
            return .string(placeholder: "Text to append to system prompt")
        case "--append-system-prompt-file":
            return .string(placeholder: "Path to file with additional system prompt")
        case "--betas":
            return .string(placeholder: "interleaved-thinking")
        case "--debug":
            return .string(placeholder: "api,hooks (or empty for all)")
        case "--debug-file":
            return .string(placeholder: "Path to debug log file")
        case "--disallowedTools":
            return .string(placeholder: "\"Bash(git log *)\" \"Edit\"")
        case "--effort":
            return .string(placeholder: "low / medium / high / xhigh / max")
        case "--max-budget-usd":
            return .string(placeholder: "5.00")
        case "--max-turns":
            return .string(placeholder: "3")
        case "--mcp-config":
            return .string(placeholder: "Path to MCP config JSON file")
        case "--model":
            return .string(placeholder: "e.g. claude-sonnet-4-6")
        case "--name":
            return .string(placeholder: "Session display name")
        case "--permission-mode":
            return .string(placeholder: "default / acceptEdits / plan / auto / dontAsk / bypassPermissions")
        case "--permission-prompt-tool":
            return .string(placeholder: "MCP tool name for permission prompts")
        case "--plugin-dir":
            return .string(placeholder: "Path to plugins directory")
        case "--resume":
            return .string(placeholder: "Session name or ID")
        case "--settings":
            return .string(placeholder: "Path to settings JSON or JSON string")
        case "--system-prompt":
            return .string(placeholder: "Custom system prompt text")
        case "--system-prompt-file":
            return .string(placeholder: "Path to system prompt file")
        case "--tools":
            return .string(placeholder: "\"Bash,Edit,Read\" or \"\" for none")
        default:
            return .boolean
        }
    }

    /// Builds raw argv tokens. Shell serialization happens once at the terminal boundary.
    func commandLineArguments(value: String?, values: [String] = []) -> [String] {
        switch optionType {
        case .boolean:
            return [id]
        case .string where allowsMultipleValues:
            var effectiveValues = values.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if effectiveValues.isEmpty {
                let raw = (value ?? "").trimmingCharacters(in: .whitespaces)
                if !raw.isEmpty { effectiveValues = [raw] }
            }
            guard !effectiveValues.isEmpty else { return [id] }
            return [id] + effectiveValues.map { Tab.expandingLeadingTilde($0) }
        case .string:
            let raw = (value ?? "").trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return [id] }
            return [id, Tab.expandingLeadingTilde(raw)]
        case .optionalString:
            let raw = (value ?? "").trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return [id] }
            return [id, Tab.expandingLeadingTilde(raw)]
        }
    }

    /// Cleans up user-edited preset drafts for persistence: trims whitespace, drops blanks, and
    /// removes duplicates while preserving first-seen order.
    static func normalizedPresetValues(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in raw {
            let trimmed = entry.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }

    static let all: [CLIOptionConfig] = [
        CLIOptionConfig(
            id: "--add-dir", label: "Add Directory",
            description: "Add additional working directories for Claude to read and edit files", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--agent", label: "Agent", description: "Specify an agent for the current session", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--agents", label: "Agents (JSON)", description: "Define custom subagents dynamically via JSON",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--allow-dangerously-skip-permissions", label: "Allow Skip Permissions",
            description: "Add bypassPermissions to Shift+Tab mode cycle without starting in it", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--allowedTools", label: "Allowed Tools",
            description: "Tools that execute without prompting for permission", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--append-system-prompt", label: "Append System Prompt",
            description: "Append custom text to the end of the default system prompt", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--append-system-prompt-file", label: "Append System Prompt File",
            description: "Append file contents to the end of the default system prompt", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--bare", label: "Bare Mode",
            description:
                "Minimal mode: skip auto-discovery of hooks, skills, plugins, MCP servers, auto memory, and CLAUDE.md",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--betas", label: "Betas", description: "Beta headers to include in API requests (API key users only)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--chrome", label: "Chrome",
            description: "Enable Chrome browser integration for web automation and testing", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--continue", label: "Continue",
            description: "Load the most recent conversation in the current directory", isAvailable: true,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--dangerously-skip-permissions", label: "Skip Permissions",
            description: "Skip all permission prompts — equivalent to bypassPermissions mode", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--debug", label: "Debug",
            description: "Enable debug mode with optional category filtering (e.g. 'api,hooks')", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--debug-file", label: "Debug File", description: "Write debug logs to a specific file path",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--disable-slash-commands", label: "Disable Slash Commands",
            description: "Disable all skills and commands for this session", isAvailable: false, isDefaultEnabled: false
        ),
        CLIOptionConfig(
            id: "--disallowedTools", label: "Disallowed Tools",
            description: "Tools that are removed from the model's context and cannot be used", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--effort", label: "Effort", description: "Set the effort level (low, medium, high, xhigh, max)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--ide", label: "IDE",
            description: "Automatically connect to IDE on startup if exactly one valid IDE is available",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--max-budget-usd", label: "Max Budget (USD)",
            description: "Maximum dollar amount to spend on API calls before stopping (print mode only)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--max-turns", label: "Max Turns", description: "Limit the number of agentic turns (print mode only)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--mcp-config", label: "MCP Config", description: "Load MCP servers from JSON files or strings",
            isAvailable: false, isDefaultEnabled: false, allowsMultipleValues: true),
        CLIOptionConfig(
            id: "--model", label: "Model", description: "Sets the model for the current session", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--name", label: "Session Name", description: "Set a display name for this session", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--no-chrome", label: "No Chrome", description: "Disable Chrome browser integration for this session",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--no-session-persistence", label: "No Session Persistence",
            description: "Disable session persistence — sessions are not saved to disk (print mode only)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--permission-mode", label: "Permission Mode", description: "Begin in a specified permission mode",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--permission-prompt-tool", label: "Permission Prompt Tool",
            description: "MCP tool to handle permission prompts in non-interactive mode", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--plugin-dir", label: "Plugin Directory",
            description: "Load plugins from a directory for this session only", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--resume", label: "Resume", description: "Resume a specific session by name or ID", isAvailable: true,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--settings", label: "Settings",
            description: "Path to a settings JSON file or a JSON string to load additional settings from",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--strict-mcp-config", label: "Strict MCP Config",
            description: "Only use MCP servers from --mcp-config, ignoring all other MCP configurations",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--system-prompt", label: "System Prompt",
            description: "Replace the entire system prompt with custom text", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--system-prompt-file", label: "System Prompt File",
            description: "Load system prompt from a file, replacing the default", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--tools", label: "Tools", description: "Restrict which built-in tools Claude can use",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--verbose", label: "Verbose", description: "Enable verbose logging with full turn-by-turn output",
            isAvailable: false, isDefaultEnabled: false),
    ]

    static let codexAll: [CLIOptionConfig] = [
        CLIOptionConfig(
            id: "--ask-for-approval", label: "Ask for Approval",
            description: "Control approval timing: untrusted, on-request, or never", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--config", label: "Config", description: "Override configuration values (JSON-parsed if possible)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--dangerously-bypass-approvals-and-sandbox", label: "Bypass Approvals and Sandbox",
            description: "Skip all approval prompts and sandbox restrictions (dangerous)", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--disable", label: "Disable Feature", description: "Force-disable a named feature flag",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--enable", label: "Enable Feature", description: "Force-enable a named feature flag",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--image", label: "Image", description: "Attach image files to the initial prompt", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--model", label: "Model", description: "Override the configured model for this session",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--no-alt-screen", label: "No Alt Screen", description: "Disable alternate screen mode for the TUI",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--oss", label: "OSS Provider", description: "Use a local open source provider (Ollama)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--profile", label: "Profile", description: "Load a named configuration profile", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--sandbox", label: "Sandbox",
            description: "Sandbox policy: read-only, workspace-write, or danger-full-access", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--search", label: "Web Search", description: "Enable live web search during the session",
            isAvailable: false, isDefaultEnabled: false),
    ]

    static let cursorAll: [CLIOptionConfig] = [
        CLIOptionConfig(
            id: "--api-key", label: "API Key",
            description: "API key for authentication (alternative to CURSOR_API_KEY env var)", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--approve-mcps", label: "Approve MCPs",
            description:
                "Automatically approve all MCP servers without prompting, including Agent Control's injected server",
            isAvailable: true, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--continue", label: "Continue", description: "Continue the previous session (alias for --resume=-1)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--force", label: "Force", description: "Force allow commands unless explicitly denied",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--header", label: "Header", description: "Add a custom header to agent requests (format: Name: Value)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--list-models", label: "List Models", description: "List all available models and exit",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--mode", label: "Mode", description: "Set agent mode: plan or ask (default is agent when unspecified)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--model", label: "Model", description: "Model to use for this session", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--output-format", label: "Output Format",
            description: "Output format when using --print: text, json, or stream-json", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--plan", label: "Plan Mode", description: "Start in plan mode (shorthand for --mode=plan)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--print", label: "Print Mode",
            description: "Print responses to console for non-interactive use (has access to all tools)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--resume", label: "Resume", description: "Resume a chat session by ID", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--sandbox", label: "Sandbox", description: "Set sandbox mode: enabled or disabled", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--stream-partial-output", label: "Stream Partial Output",
            description: "Stream partial output as individual text deltas (requires --print and stream-json)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--trust", label: "Trust", description: "Trust the workspace without prompting (headless mode only)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--workspace", label: "Workspace", description: "Workspace directory to use for this session",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--yolo", label: "Yolo",
            description: "Alias for --force: force allow commands unless explicitly denied", isAvailable: false,
            isDefaultEnabled: false),
    ]

    static let opencodeAll: [CLIOptionConfig] = [
        CLIOptionConfig(
            id: "--agent", label: "Agent", description: "Agent to use for the OpenCode session", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--auto", label: "Auto", description: "Auto-approve permissions not explicitly denied",
            isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--continue", label: "Continue", description: "Continue the last OpenCode session", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--cors", label: "CORS", description: "Additional browser origin(s) allowed for CORS",
            isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--fork", label: "Fork", description: "Fork the session when continuing", isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--model", label: "Model", description: "Model to use for the OpenCode session (provider/model)",
            isAvailable: false, isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--prompt", label: "Prompt", description: "Initial prompt to use when starting the session",
            isAvailable: false,
            isDefaultEnabled: false),
        CLIOptionConfig(
            id: "--session", label: "Session", description: "Session ID to continue", isAvailable: false,
            isDefaultEnabled: false),
    ]

    static let ompAll: [CLIOptionConfig] = {
        let booleanFlags = [
            "--advisor", "--allow-home", "--auto-approve", "--continue", "--from-claude", "--from-codex",
            "--hide-thinking", "--no-extensions", "--no-lsp", "--no-prewalk", "--no-pty", "--no-rules",
            "--no-session", "--no-skills", "--no-title", "--no-tools", "--plan-yolo", "--prewalk",
        ]
        let stringFlags = [
            "--add-dir", "--append-system-prompt", "--approval-mode", "--config", "--extension", "--hook",
            "--max-time", "--model", "--models", "--plan", "--plan-yolo-into", "--plugin-dir", "--prewalk-into",
            "--profile", "--provider", "--service-tier", "--session-dir", "--skills", "--slow", "--smol",
            "--system-prompt", "--thinking", "--tools",
        ]
        let presets: [String: [String]] = [
            "--approval-mode": ["always-ask", "write", "yolo"],
            "--thinking": ["off", "minimal", "low", "medium", "high", "xhigh", "max", "auto"],
            "--service-tier": ["none", "auto", "default", "flex", "scale", "priority"],
        ]
        let descriptions = [
            "--add-dir": "Add an additional workspace directory.",
            "--advisor": "Passively review each turn and inject advisor notes.",
            "--allow-home": "Allow starting in the home directory instead of a temporary directory.",
            "--append-system-prompt": "Append text or file contents to the system prompt.",
            "--approval-mode": "Override tool approval behavior for this session.",
            "--auto-approve": "Approve all tool calls without prompting.",
            "--config": "Load an additional config.yml-style overlay for this run.",
            "--continue": "Continue the previous session.",
            "--extension": "Load an extension file.",
            "--from-claude": "Import a Claude Code session into Oh My Pi.",
            "--from-codex": "Import a Codex session into Oh My Pi.",
            "--hide-thinking": "Hide thinking blocks in the TUI without disabling model thinking.",
            "--hook": "Load a hook or extension file.",
            "--max-time": "Stop the session after the specified duration.",
            "--model": "Select the model for this session.",
            "--models": "Limit Ctrl+P model cycling to matching models.",
            "--no-extensions": "Disable extension discovery while retaining explicitly loaded extensions.",
            "--no-lsp": "Disable LSP tools, formatting, and diagnostics.",
            "--no-prewalk": "Disable prewalk even when prewalk.enabled is set.",
            "--no-pty": "Disable PTY-based interactive bash execution.",
            "--no-rules": "Disable rules discovery and loading.",
            "--no-session": "Run without saving a session.",
            "--no-skills": "Disable skills discovery and loading.",
            "--no-title": "Disable automatic session title generation.",
            "--no-tools": "Disable all built-in tools.",
            "--plan": "Select the model used for architectural planning.",
            "--plan-yolo": "Start read-only plan mode, auto-approve it, then implement with the target model.",
            "--plan-yolo-into": "Select the model used after plan-yolo approval.",
            "--plugin-dir": "Load a plugin from a directory.",
            "--prewalk": "Switch to a fast model on the first edit after the plan todo list exists.",
            "--prewalk-into": "Select the target model used for prewalk.",
            "--profile": "Use an isolated profile for authentication, sessions, settings, and caches.",
            "--provider": "Select a provider for this session; prefer --model.",
            "--resume": "Resume a session by ID prefix or path, or open the session picker.",
            "--service-tier": "Set the OpenAI service tier for this session.",
            "--session-dir": "Set the directory used to store and find sessions.",
            "--skills": "Filter loaded skills with comma-separated glob patterns.",
            "--slow": "Select the slow reasoning model for thorough analysis.",
            "--smol": "Select the fast model for lightweight tasks.",
            "--system-prompt": "Replace the default coding-assistant system prompt.",
            "--thinking": "Set the model thinking level.",
            "--tools": "Enable only the specified comma-separated tools.",
        ]
        let optionIDs = booleanFlags + stringFlags + ["--resume"]
        precondition(
            Set(descriptions.keys) == Set(optionIDs),
            "Every Oh My Pi option must have exactly one description")

        let make: (String, Bool, Bool) -> CLIOptionConfig = { id, optionalString, stringType in
            CLIOptionConfig(
                id: id,
                label: String(id.dropFirst(2)).replacingOccurrences(of: "-", with: " ").capitalized,
                description: descriptions[id]!,
                isAvailable: false,
                isDefaultEnabled: false,
                isOptionalStringType: optionalString,
                isStringType: stringType,
                presetValues: presets[id] ?? [])
        }
        return booleanFlags.map { make($0, false, false) }
            + stringFlags.map { make($0, false, true) }
            + [make("--resume", true, false)]
    }()

    static func recommendedDefaults(for cli: Harness) -> [CLIOptionConfig] {
        let recommendedIDs: Set<String>
        switch cli {
        case .claude:
            recommendedIDs = ["--continue", "--resume", "--model", "--permission-mode"]
        case .codex:
            recommendedIDs = ["--model", "--ask-for-approval", "--sandbox", "--search"]
        case .cursor:
            recommendedIDs = ["--model", "--resume", "--mode"]
        case .opencode:
            recommendedIDs = ["--model"]
        case .omp:
            recommendedIDs = ["--model", "--thinking", "--approval-mode", "--continue", "--resume"]
        case .shell:
            return []
        }

        let catalog = CLIOptionConfig.catalog(for: cli)
        return catalog.map { option in
            var copy = option
            copy.isAvailable = recommendedIDs.contains(option.id)
            return copy
        }
    }
}
