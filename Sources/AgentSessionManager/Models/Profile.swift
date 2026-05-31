import Foundation

struct ProfileCLIOption: Codable, Equatable {
    var id: String
    var isEnabled: Bool
    var value: String?
    var showOnPaneCreate: Bool

    init(id: String, isEnabled: Bool, value: String? = nil, showOnPaneCreate: Bool = false) {
        self.id = id
        self.isEnabled = isEnabled
        self.value = value
        self.showOnPaneCreate = showOnPaneCreate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        showOnPaneCreate = try container.decodeIfPresent(Bool.self, forKey: .showOnPaneCreate) ?? false
    }
}

struct ProfileEnvVar: Codable, Equatable {
    var id: String
    var isEnabled: Bool
    var value: String
    var showOnPaneCreate: Bool

    init(id: String, isEnabled: Bool, value: String, showOnPaneCreate: Bool = false) {
        self.id = id
        self.isEnabled = isEnabled
        self.value = value
        self.showOnPaneCreate = showOnPaneCreate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        value = try container.decode(String.self, forKey: .value)
        showOnPaneCreate = try container.decodeIfPresent(Bool.self, forKey: .showOnPaneCreate) ?? false
    }
}

struct Profile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var harness: Harness
    var cliOptions: [ProfileCLIOption]
    var envVars: [ProfileEnvVar]
    var statusLineConfig: StatusLineConfig?

    init(
        id: UUID = UUID(),
        name: String,
        harness: Harness,
        cliOptions: [ProfileCLIOption] = [],
        envVars: [ProfileEnvVar] = [],
        statusLineConfig: StatusLineConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.harness = harness
        self.cliOptions = cliOptions
        self.envVars = envVars
        self.statusLineConfig = statusLineConfig
    }

    func buildArgs() -> [String] {
        var args: [String] = []
        for option in cliOptions where option.isEnabled {
            args.append(option.id)
            if let value = option.value, !value.isEmpty {
                let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
                args.append("'\(escaped)'")
            }
        }
        return args
    }

    func buildEnvVars() -> [String: String] {
        var env: [String: String] = [:]
        for envVar in envVars where envVar.isEnabled && !envVar.value.isEmpty {
            env[envVar.id] = envVar.value
        }
        return env
    }

    /// Creates a profile seeded from the current global settings.
    /// Available flags become the profile's CLI options with their default enabled state.
    @MainActor
    static func fromGlobalSettings(
        name: String,
        harness: Harness,
        appSettings: AppSettings
    ) -> Profile {
        let globalOptions: [CLIOptionConfig]
        switch harness {
        case .claude: globalOptions = appSettings.cliOptions
        case .codex: globalOptions = appSettings.codexCliOptions
        case .cursor: globalOptions = appSettings.cursorCliOptions
        case .opencode: globalOptions = appSettings.opencodeCliOptions
        case .shell: globalOptions = []
        }

        let options = globalOptions.filter(\.isAvailable).map { opt in
            ProfileCLIOption(
                id: opt.id,
                isEnabled: opt.isDefaultEnabled,
                value: nil
            )
        }

        let envVars: [ProfileEnvVar]
        if harness == .claude {
            envVars = appSettings.envVarOptions.filter(\.isAvailable).map { ev in
                ProfileEnvVar(
                    id: ev.id,
                    isEnabled: ev.isDefaultEnabled,
                    value: ev.defaultValue
                )
            }
        } else {
            envVars = []
        }

        return Profile(
            name: name,
            harness: harness,
            cliOptions: options,
            envVars: envVars
        )
    }
}
