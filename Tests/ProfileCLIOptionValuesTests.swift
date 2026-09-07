import Foundation
import Testing

@testable import AgentSessionManager

@Suite("ProfileCLIOptionValues")
struct ProfileCLIOptionValuesTests {
    @Test("values defaults to nil")
    func defaultsToNil() {
        let option = ProfileCLIOption(id: "--mcp-config", isEnabled: true)
        #expect(option.values == nil)
    }

    @Test("values round-trips through JSON")
    func roundTrips() throws {
        let original = ProfileCLIOption(id: "--mcp-config", isEnabled: true, values: ["a.json", "b.json"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProfileCLIOption.self, from: data)
        #expect(decoded.values == ["a.json", "b.json"])
    }

    @Test("Legacy JSON without values decodes as nil, preserving value")
    func legacyDecodeWithoutValues() throws {
        let json = Data(
            """
            {"id":"--mcp-config","isEnabled":true,"value":"~/mcp/legacy.json"}
            """.utf8)
        let decoded = try JSONDecoder().decode(ProfileCLIOption.self, from: json)
        #expect(decoded.values == nil)
        #expect(decoded.value == "~/mcp/legacy.json")
    }

    @Test("nil values is omitted from encoded JSON")
    func nilValuesOmittedFromEncoding() throws {
        let option = ProfileCLIOption(id: "--mcp-config", isEnabled: true)
        let data = try JSONEncoder().encode(option)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["values"] == nil)
    }

    @Test("A pre-existing single value still resolves via the single-to-multi compatibility path")
    func singleValueCompatibilityPathStillEmitsThatValue() throws {
        let json = Data(
            """
            {"id":"--mcp-config","isEnabled":true,"value":"~/mcp/legacy.json"}
            """.utf8)
        let decoded = try JSONDecoder().decode(ProfileCLIOption.self, from: json)
        let option = CLIOptionConfig.all.first { $0.id == "--mcp-config" }!
        let args = option.commandLineArguments(value: decoded.value, values: decoded.values ?? [])
        #expect(args == ["--mcp-config", "\(NSHomeDirectory())/mcp/legacy.json"])
    }

    @Test("seededValues returns values verbatim when present")
    func seededValuesReturnsValuesVerbatim() {
        let option = ProfileCLIOption(id: "--mcp-config", isEnabled: true, value: "stale.json", values: ["a", "b"])
        #expect(option.seededValues(allowsMultipleValues: true) == ["a", "b"])
    }

    @Test("seededValues promotes a pre-existing single value for multi-value flags")
    func seededValuesPromotesSingleValueForMultiValueFlag() {
        let option = ProfileCLIOption(id: "--mcp-config", isEnabled: true, value: "legacy.json")
        #expect(option.seededValues(allowsMultipleValues: true) == ["legacy.json"])
    }

    @Test("seededValues does not promote a single value for single-select flags")
    func seededValuesDoesNotPromoteForSingleSelectFlag() {
        let option = ProfileCLIOption(id: "--effort", isEnabled: true, value: "high")
        #expect(option.seededValues(allowsMultipleValues: false).isEmpty)
    }

    @Test("seededValues returns empty when there is no value or values to seed from")
    func seededValuesEmptyWhenNothingToSeed() {
        let option = ProfileCLIOption(id: "--mcp-config", isEnabled: true)
        #expect(option.seededValues(allowsMultipleValues: true).isEmpty)
    }

    @Test("seededValues trims whitespace from a promoted single value")
    func seededValuesTrimsPromotedSingleValue() {
        let option = ProfileCLIOption(id: "--mcp-config", isEnabled: true, value: "  legacy.json  ")
        #expect(option.seededValues(allowsMultipleValues: true) == ["legacy.json"])
    }

    @Test("seededValues treats a whitespace-only single value as nothing to seed")
    func seededValuesWhitespaceOnlySingleValueYieldsEmpty() {
        let option = ProfileCLIOption(id: "--mcp-config", isEnabled: true, value: "   ")
        #expect(option.seededValues(allowsMultipleValues: true).isEmpty)
    }
}
