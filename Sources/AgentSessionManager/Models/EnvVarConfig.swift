import Foundation

struct EnvVarConfig: Identifiable, Codable {
    var id: String
    var label: String
    var description: String
    var isAvailable: Bool
    var isDefaultEnabled: Bool
    var defaultValue: String
    var isUserAdded: Bool

    enum CodingKeys: String, CodingKey {
        case id, isAvailable, isDefaultEnabled, defaultValue, isUserAdded
    }

    init(
        id: String, label: String, description: String, isAvailable: Bool = false,
        isDefaultEnabled: Bool = false, defaultValue: String = "", isUserAdded: Bool = false
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.isAvailable = isAvailable
        self.isDefaultEnabled = isDefaultEnabled
        self.defaultValue = defaultValue
        self.isUserAdded = isUserAdded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let isUserAdded = (try? container.decodeIfPresent(Bool.self, forKey: .isUserAdded)) ?? false

        if isUserAdded {
            let id = try container.decode(String.self, forKey: .id)
            self.id = id
            self.label = id
            self.description = "User-defined environment variable"
            self.isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
            self.isDefaultEnabled = try container.decode(Bool.self, forKey: .isDefaultEnabled)
            self.defaultValue = (try? container.decodeIfPresent(String.self, forKey: .defaultValue)) ?? ""
            self.isUserAdded = true
        } else {
            let id = try container.decode(String.self, forKey: .id)
            guard let template = EnvVarConfig.all.first(where: { $0.id == id }) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .id, in: container, debugDescription: "Unknown env var: \(id)")
            }
            self.id = template.id
            self.label = template.label
            self.description = template.description
            self.isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
            self.isDefaultEnabled = try container.decode(Bool.self, forKey: .isDefaultEnabled)
            self.defaultValue = (try? container.decodeIfPresent(String.self, forKey: .defaultValue)) ?? ""
            self.isUserAdded = false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(isAvailable, forKey: .isAvailable)
        try container.encode(isDefaultEnabled, forKey: .isDefaultEnabled)
        if !defaultValue.isEmpty {
            try container.encode(defaultValue, forKey: .defaultValue)
        }
        if isUserAdded {
            try container.encode(true, forKey: .isUserAdded)
        }
    }

    static func makeUserAdded(id: String) -> EnvVarConfig {
        EnvVarConfig(
            id: id, label: id, description: "User-defined environment variable",
            isAvailable: true, isDefaultEnabled: false, defaultValue: "", isUserAdded: true
        )
    }

    // MARK: - Predefined Claude Code environment variables
    // Source: https://code.claude.com/docs/en/env-vars
    // Excludes deprecated vars (ANTHROPIC_SMALL_FAST_MODEL) and auto-set vars (CLAUDECODE).

    static let all: [EnvVarConfig] = [
        // --- Authentication & API Keys ---
        EnvVarConfig(
            id: "ANTHROPIC_API_KEY",
            label: "API Key",
            description: "API key sent as X-Api-Key header, used instead of subscription"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_AUTH_TOKEN",
            label: "Auth Token",
            description: "Custom Authorization header value (prefixed with Bearer)"
        ),

        // --- API Configuration ---
        EnvVarConfig(
            id: "ANTHROPIC_BASE_URL",
            label: "Base URL",
            description: "Override the API endpoint for proxy or gateway routing"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_BETAS",
            label: "Betas",
            description: "Comma-separated list of additional anthropic-beta header values"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_CUSTOM_HEADERS",
            label: "Custom Headers",
            description: "Custom headers for requests (Name: Value, newline-separated)"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_WORKSPACE_ID",
            label: "Workspace ID",
            description: "Workspace ID for workload identity federation"
        ),
        EnvVarConfig(
            id: "API_TIMEOUT_MS",
            label: "API Timeout",
            description: "Timeout for API requests in milliseconds (default: 600000)"
        ),

        // --- Model Configuration ---
        EnvVarConfig(
            id: "ANTHROPIC_MODEL",
            label: "Model",
            description: "Name of the model setting to use"
        ),

        // --- Bash / Shell ---
        EnvVarConfig(
            id: "BASH_DEFAULT_TIMEOUT_MS",
            label: "Bash Default Timeout",
            description: "Default timeout for bash commands in ms (default: 120000)"
        ),
        EnvVarConfig(
            id: "BASH_MAX_OUTPUT_LENGTH",
            label: "Bash Max Output Length",
            description: "Max characters in bash output before saving to file"
        ),
        EnvVarConfig(
            id: "BASH_MAX_TIMEOUT_MS",
            label: "Bash Max Timeout",
            description: "Maximum timeout for bash commands in ms (default: 600000)"
        ),

        // --- Compaction ---
        EnvVarConfig(
            id: "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE",
            label: "Autocompact Percentage",
            description: "Context capacity percentage (1-100) at which auto-compaction triggers"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_AUTO_COMPACT_WINDOW",
            label: "Auto Compact Window",
            description: "Context capacity in tokens for auto-compaction calculations"
        ),

        // --- Bash Behavior ---
        EnvVarConfig(
            id: "CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR",
            label: "Maintain Project Working Dir",
            description: "Return to original working directory after each Bash command"
        ),

        // --- Accessibility ---
        EnvVarConfig(
            id: "CLAUDE_CODE_ACCESSIBILITY",
            label: "Accessibility",
            description: "Set to 1 to keep native terminal cursor visible for screen magnifiers"
        ),

        // --- Memory / CLAUDE.md ---
        EnvVarConfig(
            id: "CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD",
            label: "Additional Dirs CLAUDE.md",
            description: "Set to 1 to load memory files from --add-dir directories"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_AUTO_MEMORY",
            label: "Disable Auto Memory",
            description: "Set to 1 to disable auto memory, 0 to force on"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_CLAUDE_MDS",
            label: "Disable CLAUDE.md Files",
            description: "Set to 1 to prevent loading any CLAUDE.md memory files"
        ),

        // --- Prompt / Attribution ---
        EnvVarConfig(
            id: "CLAUDE_CODE_ATTRIBUTION_HEADER",
            label: "Attribution Header",
            description: "Set to 0 to omit attribution block from system prompt"
        ),

        // --- IDE ---
        EnvVarConfig(
            id: "CLAUDE_CODE_AUTO_CONNECT_IDE",
            label: "Auto Connect IDE",
            description: "Override automatic IDE connection (true/false)"
        ),

        // --- TLS / Certificates ---
        EnvVarConfig(
            id: "CLAUDE_CODE_CERT_STORE",
            label: "Certificate Store",
            description: "CA certificate sources for TLS (default: bundled,system)"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_CLIENT_CERT",
            label: "Client Certificate",
            description: "Path to client certificate file for mTLS"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_CLIENT_KEY",
            label: "Client Key",
            description: "Path to client private key file for mTLS"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_CLIENT_KEY_PASSPHRASE",
            label: "Client Key Passphrase",
            description: "Passphrase for encrypted client key"
        ),

        // --- Debug ---
        EnvVarConfig(
            id: "CLAUDE_CODE_DEBUG_LOGS_DIR",
            label: "Debug Logs Dir",
            description: "Override the debug log file path"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DEBUG_LOG_LEVEL",
            label: "Debug Log Level",
            description: "Minimum debug log level: verbose, debug, info, warn, error"
        ),

        // --- Disable Features ---
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_1M_CONTEXT",
            label: "Disable 1M Context",
            description: "Set to 1 to disable 1M context window support"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING",
            label: "Disable Adaptive Thinking",
            description: "Set to 1 to disable adaptive reasoning on Opus/Sonnet 4.6"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_AGENT_VIEW",
            label: "Disable Agent View",
            description: "Set to 1 to turn off background agents and agent view"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN",
            label: "Disable Alternate Screen",
            description: "Set to 1 to disable fullscreen rendering"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_ATTACHMENTS",
            label: "Disable Attachments",
            description: "Set to 1 to disable @ file attachment processing"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_BACKGROUND_TASKS",
            label: "Disable Background Tasks",
            description: "Set to 1 to disable all background task functionality"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_CRON",
            label: "Disable Cron",
            description: "Set to 1 to disable scheduled tasks"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_FAST_MODE",
            label: "Disable Fast Mode",
            description: "Set to 1 to disable fast mode"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY",
            label: "Disable Feedback Survey",
            description: "Set to 1 to disable session quality surveys"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING",
            label: "Disable File Checkpointing",
            description: "Set to 1 to disable file checkpointing (/rewind)"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS",
            label: "Disable Git Instructions",
            description: "Set to 1 to remove built-in git workflow instructions"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_MOUSE",
            label: "Disable Mouse",
            description: "Set to 1 to disable mouse tracking in fullscreen mode"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
            label: "Disable Nonessential Traffic",
            description: "Disable autoupdater, feedback, error reporting, and telemetry"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL",
            label: "Disable Marketplace Autoinstall",
            description: "Set to 1 to skip auto-adding official plugin marketplace"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_POLICY_SKILLS",
            label: "Disable Policy Skills",
            description: "Set to 1 to skip loading managed skills"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_TERMINAL_TITLE",
            label: "Disable Terminal Title",
            description: "Set to 1 to disable automatic terminal title updates"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_THINKING",
            label: "Disable Thinking",
            description: "Set to 1 to force-disable extended thinking"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_DISABLE_VIRTUAL_SCROLL",
            label: "Disable Virtual Scroll",
            description: "Set to 1 to disable virtual scrolling in fullscreen mode"
        ),

        // --- Effort / Thinking ---
        EnvVarConfig(
            id: "CLAUDE_CODE_EFFORT_LEVEL",
            label: "Effort Level",
            description: "Effort level: low, medium, high, xhigh, max, or auto"
        ),

        // --- Enable Features ---
        EnvVarConfig(
            id: "CLAUDE_CODE_ENABLE_AWAY_SUMMARY",
            label: "Enable Away Summary",
            description: "Override session recap availability (0 or 1)"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_ENABLE_TELEMETRY",
            label: "Enable Telemetry",
            description: "Set to 1 to enable OpenTelemetry data collection"
        ),

        // --- Misc Configuration ---
        EnvVarConfig(
            id: "CLAUDE_CODE_EXTRA_BODY",
            label: "Extra Body",
            description: "JSON object to merge into every API request body"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS",
            label: "File Read Max Output Tokens",
            description: "Override the default token limit for file reads"
        ),

        // --- Glob ---
        EnvVarConfig(
            id: "CLAUDE_CODE_GLOB_HIDDEN",
            label: "Glob Hidden",
            description: "Set to false to exclude dotfiles from Glob results"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_GLOB_NO_IGNORE",
            label: "Glob No Ignore",
            description: "Set to false to make Glob respect .gitignore patterns"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_GLOB_TIMEOUT_SECONDS",
            label: "Glob Timeout",
            description: "Timeout in seconds for Glob file discovery (default: 20)"
        ),

        // --- Display ---
        EnvVarConfig(
            id: "CLAUDE_CODE_HIDE_CWD",
            label: "Hide CWD",
            description: "Set to 1 to hide working directory in startup logo"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_NATIVE_CURSOR",
            label: "Native Cursor",
            description: "Set to 1 to show terminal's own cursor at input caret"
        ),

        // --- Context / Tokens ---
        EnvVarConfig(
            id: "CLAUDE_CODE_MAX_CONTEXT_TOKENS",
            label: "Max Context Tokens",
            description: "Override context window size (requires DISABLE_COMPACT)"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_MAX_OUTPUT_TOKENS",
            label: "Max Output Tokens",
            description: "Maximum number of output tokens per request"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_MAX_RETRIES",
            label: "Max Retries",
            description: "Number of times to retry failed API requests (default: 10)"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY",
            label: "Max Tool Use Concurrency",
            description: "Max parallel read-only tools and subagents (default: 10)"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_MAX_TURNS",
            label: "Max Turns",
            description: "Cap the number of agentic turns"
        ),

        // --- MCP ---
        EnvVarConfig(
            id: "CLAUDE_CODE_MCP_ALLOWLIST_ENV",
            label: "MCP Allowlist Env",
            description: "Set to 1 to restrict MCP server environment inheritance"
        ),

        // --- Notifications ---
        EnvVarConfig(
            id: "CLAUDE_CODE_NOTIFICATION_FILTER",
            label: "Notification Filter",
            description: "Notification level: all, warnings, errors"
        ),

        // --- OpenTelemetry ---
        EnvVarConfig(
            id: "CLAUDE_CODE_OTEL_ENDPOINT",
            label: "OTel Endpoint",
            description: "OpenTelemetry collector endpoint URL"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_OTEL_HEADERS",
            label: "OTel Headers",
            description: "Headers to include with OpenTelemetry requests"
        ),

        // --- Telemetry / Traffic Control ---
        EnvVarConfig(
            id: "DISABLE_AUTOUPDATER",
            label: "Disable Autoupdater",
            description: "Set to 1 to disable automatic updates"
        ),
        EnvVarConfig(
            id: "DISABLE_ERROR_REPORTING",
            label: "Disable Error Reporting",
            description: "Set to 1 to disable error reporting"
        ),
        EnvVarConfig(
            id: "DISABLE_TELEMETRY",
            label: "Disable Telemetry",
            description: "Set to 1 to disable telemetry collection"
        ),
        EnvVarConfig(
            id: "DO_NOT_TRACK",
            label: "Do Not Track",
            description: "Set to 1 to disable tracking"
        ),

        // --- Compact ---
        EnvVarConfig(
            id: "DISABLE_COMPACT",
            label: "Disable Compact",
            description: "Set to 1 to disable auto-compaction"
        ),

        // --- Debug ---
        EnvVarConfig(
            id: "DEBUG",
            label: "Debug",
            description: "Set to 1 to enable debug mode"
        ),
    ]
}
