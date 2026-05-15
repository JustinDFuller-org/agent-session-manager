import Foundation

struct ProfileCLIOption: Codable, Equatable {
    var id: String
    var isEnabled: Bool
    var value: String?
}

struct ProfileEnvVar: Codable, Equatable {
    var id: String
    var isEnabled: Bool
    var value: String
}

struct Profile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var cliType: CLIType
    var cliOptions: [ProfileCLIOption]
    var envVars: [ProfileEnvVar]
    var statusLineConfig: StatusLineConfig?

    init(
        id: UUID = UUID(),
        name: String,
        cliType: CLIType,
        cliOptions: [ProfileCLIOption] = [],
        envVars: [ProfileEnvVar] = [],
        statusLineConfig: StatusLineConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.cliType = cliType
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
        for v in envVars where v.isEnabled && !v.value.isEmpty {
            env[v.id] = v.value
        }
        return env
    }

    /// Creates a profile seeded from the current global settings.
    /// Available flags become the profile's CLI options with their default enabled state.
    @MainActor
    static func fromGlobalSettings(
        name: String,
        cliType: CLIType,
        appSettings: AppSettings
    ) -> Profile {
        let globalOptions: [CLIOptionConfig]
        switch cliType {
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
        if cliType == .claude {
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
            cliType: cliType,
            cliOptions: options,
            envVars: envVars
        )
    }
}
