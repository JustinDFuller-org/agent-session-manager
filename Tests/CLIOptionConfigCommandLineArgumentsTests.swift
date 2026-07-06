import Foundation
import Testing

@testable import AgentSessionManager

@Suite("CLIOptionConfigCommandLineArguments")
struct CLIOptionConfigCommandLineArgumentsTests {
    private func option(_ id: String) -> CLIOptionConfig {
        CLIOptionConfig.all.first { $0.id == id }!
    }

    @Test("Boolean flag returns just the flag")
    func booleanReturnsFlagOnly() {
        #expect(option("--verbose").commandLineArguments(value: "") == ["--verbose"])
    }

    @Test("Empty string value returns just the flag")
    func stringEmptyReturnsFlagOnly() {
        #expect(option("--model").commandLineArguments(value: "") == ["--model"])
    }

    @Test("Nil value is treated as empty")
    func stringNilValueReturnsFlagOnly() {
        #expect(option("--model").commandLineArguments(value: nil) == ["--model"])
    }

    @Test("Whitespace-only value returns just the flag")
    func stringWhitespaceOnlyReturnsFlagOnly() {
        #expect(option("--model").commandLineArguments(value: "   ") == ["--model"])
    }

    @Test("Non-empty string value is shell-quoted")
    func stringNonEmptyIsShellQuoted() {
        #expect(option("--model").commandLineArguments(value: "claude-opus-4-7") == ["--model", "'claude-opus-4-7'"])
    }

    @Test("Leading tilde expands before quoting")
    func stringExpandsLeadingTilde() {
        let result = option("--system-prompt-file").commandLineArguments(value: "~/.claude/prompt.txt")
        #expect(result == ["--system-prompt-file", "'\(NSHomeDirectory())/.claude/prompt.txt'"])
    }

    @Test("Embedded single quotes are escaped")
    func stringEscapesSingleQuotes() {
        let result = option("--system-prompt").commandLineArguments(value: "it's custom")
        #expect(result == ["--system-prompt", "'it'\\''s custom'"])
    }

    @Test("Surrounding whitespace is trimmed before quoting")
    func stringTrimsSurroundingWhitespace() {
        let result = option("--model").commandLineArguments(value: "  claude-opus-4-7  ")
        #expect(result == ["--model", "'claude-opus-4-7'"])
    }

    // MARK: - Multi-value flags (--mcp-config)

    @Test("Multi-value flag with no values returns just the flag")
    func multiValueEmptyReturnsFlagOnly() {
        #expect(option("--mcp-config").commandLineArguments(value: nil, values: []) == ["--mcp-config"])
    }

    @Test("Multi-value flag emits one quoted argument per value, space-separated under one flag")
    func multiValueEmitsQuotedArgumentPerValue() {
        let result = option("--mcp-config").commandLineArguments(value: nil, values: ["a.json", "b.json"])
        #expect(result == ["--mcp-config", "'a.json'", "'b.json'"])
    }

    @Test("Multi-value flag expands tilde and escapes quotes per entry")
    func multiValueExpandsTildeAndEscapesPerEntry() {
        let result = option("--mcp-config").commandLineArguments(value: nil, values: ["~/mcp/a.json", "it's.json"])
        #expect(result == ["--mcp-config", "'\(NSHomeDirectory())/mcp/a.json'", "'it'\\''s.json'"])
    }

    @Test("Multi-value flag filters out whitespace-only entries")
    func multiValueFiltersWhitespaceOnlyEntries() {
        let result = option("--mcp-config").commandLineArguments(value: nil, values: ["a.json", "   ", "b.json"])
        #expect(result == ["--mcp-config", "'a.json'", "'b.json'"])
    }

    @Test("Multi-value flag falls back to a single legacy value when values is empty")
    func multiValueSingleLegacyValueCompatibilityPath() {
        let result = option("--mcp-config").commandLineArguments(value: "~/mcp/legacy.json", values: [])
        #expect(result == ["--mcp-config", "'\(NSHomeDirectory())/mcp/legacy.json'"])
    }

    @Test("Multi-value flag prefers values over a stale single value when both are present")
    func multiValuePrefersValuesOverStaleSingleValue() {
        let result = option("--mcp-config").commandLineArguments(value: "stale.json", values: ["current.json"])
        #expect(result == ["--mcp-config", "'current.json'"])
    }
}
