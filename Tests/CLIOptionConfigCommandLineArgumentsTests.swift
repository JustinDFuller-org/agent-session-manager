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

    @Test("Non-empty string value is a raw token")
    func stringNonEmptyIsRawToken() {
        #expect(option("--model").commandLineArguments(value: "claude-opus-4-7") == ["--model", "claude-opus-4-7"])
    }

    @Test("Leading tilde expands before token emission")
    func stringExpandsLeadingTilde() {
        let result = option("--system-prompt-file").commandLineArguments(value: "~/.claude/prompt.txt")
        #expect(result == ["--system-prompt-file", "\(NSHomeDirectory())/.claude/prompt.txt"])
    }

    @Test("Embedded single quotes remain in the raw token")
    func stringPreservesSingleQuotes() {
        let result = option("--system-prompt").commandLineArguments(value: "it's custom")
        #expect(result == ["--system-prompt", "it's custom"])
    }

    @Test("Surrounding whitespace is trimmed before token emission")
    func stringTrimsSurroundingWhitespace() {
        let result = option("--model").commandLineArguments(value: "  claude-opus-4-7  ")
        #expect(result == ["--model", "claude-opus-4-7"])
    }

    // MARK: - Multi-value flags (--mcp-config)

    @Test("Multi-value flag with no values returns just the flag")
    func multiValueEmptyReturnsFlagOnly() {
        #expect(option("--mcp-config").commandLineArguments(value: nil, values: []) == ["--mcp-config"])
    }

    @Test("Multi-value flag emits one raw argument per value")
    func multiValueEmitsRawArgumentPerValue() {
        let result = option("--mcp-config").commandLineArguments(value: nil, values: ["a.json", "b.json"])
        #expect(result == ["--mcp-config", "a.json", "b.json"])
    }

    @Test("Multi-value flag expands tilde and preserves quotes per entry")
    func multiValueExpandsTildeAndPreservesPerEntry() {
        let result = option("--mcp-config").commandLineArguments(value: nil, values: ["~/mcp/a.json", "it's.json"])
        #expect(result == ["--mcp-config", "\(NSHomeDirectory())/mcp/a.json", "it's.json"])
    }

    @Test("Multi-value flag filters out whitespace-only entries")
    func multiValueFiltersWhitespaceOnlyEntries() {
        let result = option("--mcp-config").commandLineArguments(value: nil, values: ["a.json", "   ", "b.json"])
        #expect(result == ["--mcp-config", "a.json", "b.json"])
    }

    @Test("Multi-value flag falls back to a single legacy value when values is empty")
    func multiValueSingleLegacyValueCompatibilityPath() {
        let result = option("--mcp-config").commandLineArguments(value: "~/mcp/legacy.json", values: [])
        #expect(result == ["--mcp-config", "\(NSHomeDirectory())/mcp/legacy.json"])
    }

    @Test("Multi-value flag prefers values over a stale single value when both are present")
    func multiValuePrefersValuesOverStaleSingleValue() {
        let result = option("--mcp-config").commandLineArguments(value: "stale.json", values: ["current.json"])
        #expect(result == ["--mcp-config", "current.json"])
    }

    @Test("Argv emission is generic across any flag marked allowsMultipleValues, not just --mcp-config")
    func multiValueEmissionIsGenericAcrossFlags() {
        var arbitraryFlag = option("--allowedTools")
        arbitraryFlag.allowsMultipleValues = true
        let result = arbitraryFlag.commandLineArguments(value: nil, values: ["Read", "Bash(git log *)"])
        #expect(result == ["--allowedTools", "Read", "Bash(git log *)"])
    }

    @Test("Oh My Pi required-value flag preserves the following option")
    func ohMyPiRequiredValueDoesNotConsumeFollowingFlag() {
        let thinking = CLIOptionConfig.ompAll.first { $0.id == "--thinking" }!
        let autoApprove = CLIOptionConfig.ompAll.first { $0.id == "--auto-approve" }!

        #expect(
            thinking.commandLineArguments(value: "off") + autoApprove.commandLineArguments(value: nil)
                == ["--thinking", "off", "--auto-approve"]
        )
    }

    @Test("Oh My Pi empty resume opens the picker")
    func ohMyPiEmptyResumeEmitsOnlyFlag() {
        let resume = CLIOptionConfig.ompAll.first { $0.id == "--resume" }!

        #expect(resume.commandLineArguments(value: "") == ["--resume"])
        #expect(resume.commandLineArguments(value: "session-id") == ["--resume", "session-id"])
    }
}
