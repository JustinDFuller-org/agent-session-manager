import Foundation

struct ProfileCLIOption: Codable, Equatable {
    var id: String
    var isEnabled: Bool
    var value: String?
    /// Selected values for a multi-value flag (e.g. `--mcp-config`). Single-select flags use `value` instead.
    var values: [String]?
    var showOnPaneCreate: Bool

    init(
        id: String, isEnabled: Bool, value: String? = nil, values: [String]? = nil, showOnPaneCreate: Bool = false
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.value = value
        self.values = values
        self.showOnPaneCreate = showOnPaneCreate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        values = try container.decodeIfPresent([String].self, forKey: .values)
        showOnPaneCreate = try container.decodeIfPresent(Bool.self, forKey: .showOnPaneCreate) ?? false
    }

    /// Resolves the values to seed an editable multi-select field with: `values` verbatim when
    /// present, otherwise a pre-existing single `value` promoted to `[value]` for multi-value
    /// flags, so a profile saved before presets existed keeps showing its selection.
    func seededValues(allowsMultipleValues: Bool) -> [String] {
        if let values, !values.isEmpty { return values }
        guard allowsMultipleValues, let value else { return [] }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? [] : [trimmed]
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
}
