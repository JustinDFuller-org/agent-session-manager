import Foundation
import Testing

@testable import AgentSessionManager

@Suite("NewPaneSheetBuildExtraArgs")
struct NewPaneSheetBuildExtraArgsTests {
    private func option(_ id: String) -> CLIOptionConfig {
        CLIOptionConfig.all.first { $0.id == id }!
    }

    @Test("A selected MCP config no longer swallows the following flag's value")
    func mcpConfigSelectionDoesNotSwallowFollowingFlag() {
        let options = [option("--mcp-config"), option("--model")]
        let states: [String: OptionState] = [
            "--mcp-config": OptionState(enabled: true, value: "", values: ["a.json"]),
            "--model": OptionState(enabled: true, value: "claude-sonnet-5[1m]"),
        ]
        let args = NewPaneSheet.buildExtraArgs(options: options, states: states)
        #expect(args == ["--mcp-config", "'a.json'", "--model", "'claude-sonnet-5[1m]'"])
    }

    @Test("Multiple selected MCP servers all emit under one flag")
    func multipleMcpConfigValuesEmitUnderOneFlag() {
        let options = [option("--mcp-config"), option("--model")]
        let states: [String: OptionState] = [
            "--mcp-config": OptionState(enabled: true, value: "", values: ["a.json", "b.json"]),
            "--model": OptionState(enabled: true, value: "claude-sonnet-5[1m]"),
        ]
        let args = NewPaneSheet.buildExtraArgs(options: options, states: states)
        #expect(args == ["--mcp-config", "'a.json'", "'b.json'", "--model", "'claude-sonnet-5[1m]'"])
    }

    @Test("A disabled option contributes nothing regardless of its values")
    func disabledOptionContributesNothing() {
        let options = [option("--mcp-config"), option("--model")]
        let states: [String: OptionState] = [
            "--mcp-config": OptionState(enabled: false, value: "", values: ["a.json"]),
            "--model": OptionState(enabled: true, value: "claude-sonnet-5[1m]"),
        ]
        let args = NewPaneSheet.buildExtraArgs(options: options, states: states)
        #expect(args == ["--model", "'claude-sonnet-5[1m]'"])
    }

    @Test("Output order follows the options list order")
    func outputOrderFollowsOptionsListOrder() {
        let options = [option("--model"), option("--mcp-config")]
        let states: [String: OptionState] = [
            "--mcp-config": OptionState(enabled: true, value: "", values: ["a.json"]),
            "--model": OptionState(enabled: true, value: "claude-sonnet-5[1m]"),
        ]
        let args = NewPaneSheet.buildExtraArgs(options: options, states: states)
        #expect(args == ["--model", "'claude-sonnet-5[1m]'", "--mcp-config", "'a.json'"])
    }
}
