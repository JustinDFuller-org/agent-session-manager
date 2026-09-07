import Foundation
import Testing

@testable import AgentSessionManager

@Suite("CLIOptionConfigPresetValues")
struct CLIOptionConfigPresetValuesTests {
    @Test("Official flag defaults to no presets")
    func defaultsToEmpty() {
        let option = CLIOptionConfig.all.first { $0.id == "--effort" }!
        #expect(option.presetValues.isEmpty)
    }

    @Test("presetValues round-trips through JSON")
    func roundTrips() throws {
        var option = CLIOptionConfig.all.first { $0.id == "--effort" }!
        option.presetValues = ["low", "high"]
        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(CLIOptionConfig.self, from: data)
        #expect(decoded.presetValues == ["low", "high"])
    }

    @Test("Empty presetValues is omitted from encoded JSON")
    func emptyOmittedFromEncoding() throws {
        let option = CLIOptionConfig.all.first { $0.id == "--effort" }!
        let data = try JSONEncoder().encode(option)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["presetValues"] == nil)
    }

    @Test("Legacy JSON without presetValues decodes to empty, preserving other fields")
    func legacyDecodeWithoutPresetValues() throws {
        let json = Data(
            """
            {"id":"--effort","isAvailable":true,"isDefaultEnabled":false}
            """.utf8)
        let decoded = try JSONDecoder().decode(CLIOptionConfig.self, from: json)
        #expect(decoded.presetValues.isEmpty)
        #expect(decoded.isAvailable == true)
        #expect(decoded.isDefaultEnabled == false)
    }

    @Test("User-added flag presetValues round-trips too")
    func userAddedRoundTrips() throws {
        var option = CLIOptionConfig(
            id: "--my-flag", label: "--my-flag", description: "User-defined option",
            isAvailable: true, isDefaultEnabled: false, isUserAdded: true, customIsStringType: true)
        option.presetValues = ["a", "b"]
        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(CLIOptionConfig.self, from: data)
        #expect(decoded.presetValues == ["a", "b"])
        #expect(decoded.isUserAdded)
    }

    @Test("--mcp-config allows multiple values")
    func mcpConfigAllowsMultipleValues() {
        let option = CLIOptionConfig.all.first { $0.id == "--mcp-config" }!
        #expect(option.allowsMultipleValues)
    }

    @Test("--effort does not allow multiple values")
    func effortDoesNotAllowMultipleValues() {
        let option = CLIOptionConfig.all.first { $0.id == "--effort" }!
        #expect(!option.allowsMultipleValues)
    }

    @Test("A user-added flag never allows multiple values, even if its id matches a multi-value flag")
    func userAddedNeverAllowsMultipleValues() {
        let option = CLIOptionConfig(
            id: "--mcp-config", label: "--mcp-config", description: "User-defined option",
            isAvailable: true, isDefaultEnabled: false, isUserAdded: true, customIsStringType: true)
        #expect(!option.allowsMultipleValues)
    }

    @Test("allowsMultipleValues round-trips through JSON for a non-mcp-config flag")
    func allowsMultipleValuesRoundTripsForOtherFlag() throws {
        var option = CLIOptionConfig.all.first { $0.id == "--allowedTools" }!
        option.allowsMultipleValues = true
        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(CLIOptionConfig.self, from: data)
        #expect(decoded.allowsMultipleValues)
    }

    @Test("Legacy JSON without allowsMultipleValues decodes to the catalog default")
    func legacyDecodeWithoutAllowsMultipleValues() throws {
        let mcpConfigJSON = Data(
            """
            {"id":"--mcp-config","isAvailable":true,"isDefaultEnabled":false}
            """.utf8)
        let decodedMcpConfig = try JSONDecoder().decode(CLIOptionConfig.self, from: mcpConfigJSON)
        #expect(decodedMcpConfig.allowsMultipleValues)

        let effortJSON = Data(
            """
            {"id":"--effort","isAvailable":true,"isDefaultEnabled":false}
            """.utf8)
        let decodedEffort = try JSONDecoder().decode(CLIOptionConfig.self, from: effortJSON)
        #expect(!decodedEffort.allowsMultipleValues)
    }

    @Test("normalizedPresetValues drops blank and whitespace-only drafts")
    func normalizedPresetValuesDropsBlanks() {
        let result = CLIOptionConfig.normalizedPresetValues(["low", "", "  ", "high"])
        #expect(result == ["low", "high"])
    }

    @Test("normalizedPresetValues trims surrounding whitespace")
    func normalizedPresetValuesTrimsWhitespace() {
        let result = CLIOptionConfig.normalizedPresetValues(["  low  ", " high"])
        #expect(result == ["low", "high"])
    }

    @Test("normalizedPresetValues de-duplicates while preserving first-seen order")
    func normalizedPresetValuesDeduplicates() {
        let result = CLIOptionConfig.normalizedPresetValues(["high", "low", "high", "medium", "low"])
        #expect(result == ["high", "low", "medium"])
    }

    @Test("normalizedPresetValues on an all-blank draft list returns empty")
    func normalizedPresetValuesAllBlankReturnsEmpty() {
        let result = CLIOptionConfig.normalizedPresetValues(["", "   ", ""])
        #expect(result.isEmpty)
    }

    @MainActor
    @Test("mergeCLIOptions preserves presetValues from saved settings")
    func mergePreservesPresetValues() {
        var saved = CLIOptionConfig.all.first { $0.id == "--effort" }!
        saved.presetValues = ["low", "high"]
        let merged = SettingsPersistence.mergeCLIOptions([saved], into: CLIOptionConfig.all)
        let mergedOption = merged.first { $0.id == "--effort" }
        #expect(mergedOption?.presetValues == ["low", "high"])
    }

    @MainActor
    @Test("mergeCLIOptions still preserves isAvailable and isDefaultEnabled alongside presetValues")
    func mergeStillPreservesExistingFields() {
        var saved = CLIOptionConfig.all.first { $0.id == "--effort" }!
        saved.isAvailable = true
        saved.isDefaultEnabled = true
        saved.presetValues = ["low"]
        let merged = SettingsPersistence.mergeCLIOptions([saved], into: CLIOptionConfig.all)
        let mergedOption = merged.first { $0.id == "--effort" }
        #expect(mergedOption?.isAvailable == true)
        #expect(mergedOption?.isDefaultEnabled == true)
        #expect(mergedOption?.presetValues == ["low"])
    }

    @MainActor
    @Test("mergeCLIOptions preserves a saved allowsMultipleValues override against catalog defaults")
    func mergePreservesAllowsMultipleValuesOverride() {
        var saved = CLIOptionConfig.all.first { $0.id == "--allowedTools" }!
        saved.allowsMultipleValues = true
        let merged = SettingsPersistence.mergeCLIOptions([saved], into: CLIOptionConfig.all)
        let mergedOption = merged.first { $0.id == "--allowedTools" }
        #expect(mergedOption?.allowsMultipleValues == true)
    }
}
