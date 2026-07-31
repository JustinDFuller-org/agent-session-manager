import Testing

@testable import AgentSessionManager

@Suite("PaneCreationSummary")
struct PaneCreationSummaryTests {
    @Test("Empty summary explains that options can be configured")
    func emptySummary() {
        let summary = PaneCreationSummary(
            configuredOptionIDs: [],
            configuredEnvironmentVariableIDs: [],
            additionalOptionCount: 3,
            additionalEnvironmentVariableCount: 0
        )

        #expect(summary.configuredCount == 0)
        #expect(summary.title == "Configure options for this pane")
        #expect(summary.detail == "3 more available")
    }

    @Test("Configured flags and environment variables are summarized without values")
    func configuredSummaryDoesNotExposeValues() {
        let summary = PaneCreationSummary(
            configuredOptionIDs: ["--mcp-config", "--model", "--continue", "--resume"],
            configuredEnvironmentVariableIDs: ["ANTHROPIC_API_KEY"],
            additionalOptionCount: 2,
            additionalEnvironmentVariableCount: 1
        )

        #expect(summary.configuredCount == 5)
        #expect(summary.title == "5 options configured")
        #expect(
            summary.detail
                == "--mcp-config, --model, --continue • 1 environment variable • 1 more flags • 3 more available")
        #expect(!summary.detail.contains("sk-"))
    }

    @Test("A single configured value uses singular copy")
    func singularSummary() {
        let summary = PaneCreationSummary(
            configuredOptionIDs: ["--continue"],
            configuredEnvironmentVariableIDs: [],
            additionalOptionCount: 0,
            additionalEnvironmentVariableCount: 0
        )

        #expect(summary.title == "1 option configured")
        #expect(summary.detail == "--continue")
    }
}
