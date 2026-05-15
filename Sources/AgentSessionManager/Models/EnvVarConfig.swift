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

        // --- AWS / Bedrock ---
        EnvVarConfig(
            id: "ANTHROPIC_AWS_API_KEY",
            label: "AWS API Key",
            description: "Workspace API key for Claude Platform on AWS"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_AWS_BASE_URL",
            label: "AWS Base URL",
            description: "Override Claude Platform on AWS endpoint URL"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_AWS_WORKSPACE_ID",
            label: "AWS Workspace ID",
            description: "Required workspace ID for Claude Platform on AWS"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_BEDROCK_BASE_URL",
            label: "Bedrock Base URL",
            description: "Override the Bedrock endpoint URL"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_BEDROCK_MANTLE_BASE_URL",
            label: "Bedrock Mantle Base URL",
            description: "Override the Bedrock Mantle endpoint URL"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_BEDROCK_SERVICE_TIER",
            label: "Bedrock Service Tier",
            description: "Bedrock service tier: default, flex, or priority"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION",
            label: "Small Fast Model AWS Region",
            description: "Override AWS region for the Haiku-class model on Bedrock"
        ),
        EnvVarConfig(
            id: "AWS_BEARER_TOKEN_BEDROCK",
            label: "Bedrock Bearer Token",
            description: "Bedrock API key for authentication"
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
        EnvVarConfig(
            id: "ANTHROPIC_CUSTOM_MODEL_OPTION",
            label: "Custom Model Option",
            description: "Model ID to add as a custom entry in the /model picker"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION",
            label: "Custom Model Description",
            description: "Display description for the custom model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME",
            label: "Custom Model Name",
            description: "Display name for the custom model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_CUSTOM_MODEL_OPTION_SUPPORTED_CAPABILITIES",
            label: "Custom Model Capabilities",
            description: "Supported capabilities for the custom model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_HAIKU_MODEL",
            label: "Default Haiku Model",
            description: "Override the default Haiku-class model"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION",
            label: "Default Haiku Model Description",
            description: "Display description for the Haiku model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME",
            label: "Default Haiku Model Name",
            description: "Display name for the Haiku model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_HAIKU_MODEL_SUPPORTED_CAPABILITIES",
            label: "Default Haiku Model Capabilities",
            description: "Supported capabilities for the Haiku model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_OPUS_MODEL",
            label: "Default Opus Model",
            description: "Override the default Opus-class model"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_OPUS_MODEL_DESCRIPTION",
            label: "Default Opus Model Description",
            description: "Display description for the Opus model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME",
            label: "Default Opus Model Name",
            description: "Display name for the Opus model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_OPUS_MODEL_SUPPORTED_CAPABILITIES",
            label: "Default Opus Model Capabilities",
            description: "Supported capabilities for the Opus model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_SONNET_MODEL",
            label: "Default Sonnet Model",
            description: "Override the default Sonnet-class model"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_SONNET_MODEL_DESCRIPTION",
            label: "Default Sonnet Model Description",
            description: "Display description for the Sonnet model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME",
            label: "Default Sonnet Model Name",
            description: "Display name for the Sonnet model entry"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_DEFAULT_SONNET_MODEL_SUPPORTED_CAPABILITIES",
            label: "Default Sonnet Model Capabilities",
            description: "Supported capabilities for the Sonnet model entry"
        ),

        // --- Microsoft Foundry ---
        EnvVarConfig(
            id: "ANTHROPIC_FOUNDRY_API_KEY",
            label: "Foundry API Key",
            description: "API key for Microsoft Foundry authentication"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_FOUNDRY_BASE_URL",
            label: "Foundry Base URL",
            description: "Full base URL for the Foundry resource"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_FOUNDRY_RESOURCE",
            label: "Foundry Resource",
            description: "Foundry resource name (required if base URL not set)"
        ),

        // --- Google Vertex AI ---
        EnvVarConfig(
            id: "ANTHROPIC_VERTEX_BASE_URL",
            label: "Vertex Base URL",
            description: "Override the Vertex AI endpoint URL"
        ),
        EnvVarConfig(
            id: "ANTHROPIC_VERTEX_PROJECT_ID",
            label: "Vertex Project ID",
            description: "GCP project ID for Vertex AI requests"
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

        // --- Remote / Cloud ---
        EnvVarConfig(
            id: "CCR_FORCE_BUNDLE",
            label: "Force Bundle",
            description: "Set to 1 to force bundle upload for claude --remote"
        ),

        // --- Agent / SDK ---
        EnvVarConfig(
            id: "CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS",
            label: "SDK Disable Builtin Agents",
            description: "Set to 1 to disable built-in subagent types in non-interactive mode"
        ),
        EnvVarConfig(
            id: "CLAUDE_AGENT_SDK_MCP_NO_PREFIX",
            label: "SDK MCP No Prefix",
            description: "Set to 1 to skip mcp__ prefix on tool names from SDK MCP servers"
        ),
        EnvVarConfig(
            id: "CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS",
            label: "Async Agent Stall Timeout",
            description: "Stall timeout in ms for background subagents (default: 600000)"
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

        // --- Background Tasks ---
        EnvVarConfig(
            id: "CLAUDE_AUTO_BACKGROUND_TASKS",
            label: "Auto Background Tasks",
            description: "Set to 1 to auto-background long-running agent tasks"
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

        // --- API Key Helper ---
        EnvVarConfig(
            id: "CLAUDE_CODE_API_KEY_HELPER_TTL_MS",
            label: "API Key Helper TTL",
            description: "Interval in ms for credential refresh with apiKeyHelper"
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
        EnvVarConfig(
            id: "CLAUDE_CODE_IDE_HOST_OVERRIDE",
            label: "IDE Host Override",
            description: "Override the host address for IDE extension connection"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL",
            label: "IDE Skip Auto Install",
            description: "Skip auto-installation of IDE extensions"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_IDE_SKIP_VALID_CHECK",
            label: "IDE Skip Valid Check",
            description: "Set to 1 to skip IDE lockfile validation during connection"
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
            id: "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS",
            label: "Disable Experimental Betas",
            description: "Set to 1 to strip anthropic-beta headers from API requests"
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
            id: "CLAUDE_CODE_DISABLE_LEGACY_MODEL_REMAP",
            label: "Disable Legacy Model Remap",
            description: "Set to 1 to prevent auto-remapping of older Opus models"
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
            id: "CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK",
            label: "Disable Nonstreaming Fallback",
            description: "Set to 1 to disable non-streaming fallback on stream errors"
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
            id: "CLAUDE_CODE_ENABLE_BACKGROUND_PLUGIN_REFRESH",
            label: "Enable Background Plugin Refresh",
            description: "Set to 1 to refresh plugin state at turn boundaries"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL",
            label: "Enable Feedback Survey for OTel",
            description: "Set to 1 to route feedback survey to OpenTelemetry"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING",
            label: "Enable Fine-Grained Tool Streaming",
            description: "Control whether tool call inputs stream as generated (0 or 1)"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY",
            label: "Enable Gateway Model Discovery",
            description: "Set to 1 to populate /model picker from gateway endpoint"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_ENABLE_OPUS_4_7_FAST_MODE",
            label: "Enable Opus 4.7 Fast Mode",
            description: "Set to 1 to run fast mode on Opus 4.7 instead of 4.6"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION",
            label: "Enable Prompt Suggestion",
            description: "Set to false to disable prompt suggestions"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_ENABLE_TASKS",
            label: "Enable Tasks",
            description: "Set to 1 to enable task tracking in non-interactive mode"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_ENABLE_TELEMETRY",
            label: "Enable Telemetry",
            description: "Set to 1 to enable OpenTelemetry data collection"
        ),

        // --- Experimental ---
        EnvVarConfig(
            id: "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS",
            label: "Experimental Agent Teams",
            description: "Set to 1 to enable agent teams (experimental)"
        ),

        // --- Misc Configuration ---
        EnvVarConfig(
            id: "CLAUDE_CODE_EXIT_AFTER_STOP_DELAY",
            label: "Exit After Stop Delay",
            description: "Delay in ms before auto-exit when idle (SDK mode)"
        ),
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
        EnvVarConfig(
            id: "CLAUDE_CODE_FORCE_SYNC_OUTPUT",
            label: "Force Sync Output",
            description: "Set to 1 to force-enable synchronized output"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_FORK_SUBAGENT",
            label: "Fork Subagent",
            description: "Set to 1 to enable forked subagents with full context"
        ),
        EnvVarConfig(
            id: "CLAUDE_CODE_GIT_BASH_PATH",
            label: "Git Bash Path",
            description: "Windows only: path to Git Bash executable"
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

        // --- Init ---
        EnvVarConfig(
            id: "CLAUDE_CODE_NEW_INIT",
            label: "New Init",
            description: "Set to 1 to make /init run interactive setup flow"
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

        // --- Thinking ---
        EnvVarConfig(
            id: "MAX_THINKING_TOKENS",
            label: "Max Thinking Tokens",
            description: "Fixed thinking budget when adaptive thinking is disabled"
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

        // --- Tool Search ---
        EnvVarConfig(
            id: "ENABLE_TOOL_SEARCH",
            label: "Enable Tool Search",
            description: "Set to true to enable MCP tool search with proxy"
        ),

        // --- Debug ---
        EnvVarConfig(
            id: "DEBUG",
            label: "Debug",
            description: "Set to 1 to enable debug mode"
        ),
    ]
}
