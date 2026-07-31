import Foundation

struct PaneCreationSummary: Equatable {
    let configuredOptionIDs: [String]
    let configuredEnvironmentVariableIDs: [String]
    let additionalOptionCount: Int
    let additionalEnvironmentVariableCount: Int

    var configuredCount: Int {
        configuredOptionIDs.count + configuredEnvironmentVariableIDs.count
    }

    var additionalCount: Int {
        additionalOptionCount + additionalEnvironmentVariableCount
    }

    var title: String {
        if configuredCount == 0 {
            return additionalCount == 0 ? "No pane-specific options" : "Configure options for this pane"
        }
        return configuredCount == 1 ? "1 option configured" : "\(configuredCount) options configured"
    }

    var detail: String {
        var parts: [String] = []
        let visibleOptionIDs = configuredOptionIDs.prefix(3)
        if !visibleOptionIDs.isEmpty {
            parts.append(visibleOptionIDs.joined(separator: ", "))
        }
        if !configuredEnvironmentVariableIDs.isEmpty {
            let count = configuredEnvironmentVariableIDs.count
            parts.append(count == 1 ? "1 environment variable" : "\(count) environment variables")
        }
        if configuredOptionIDs.count > visibleOptionIDs.count {
            parts.append("\(configuredOptionIDs.count - visibleOptionIDs.count) more flags")
        }
        if additionalCount > 0 {
            parts.append("\(additionalCount) more available")
        }
        if parts.isEmpty {
            return "Choose CLI flags, MCP servers, or environment variables."
        }
        return parts.joined(separator: " • ")
    }
}
