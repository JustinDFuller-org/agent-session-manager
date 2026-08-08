import Foundation

struct OhMyPiLaunchPolicy: Equatable {
    let arguments: [String]
    let expectedSessionID: String?

    static func validationError(arguments: [String]) -> String? {
        let sessionSelectors = arguments.compactMap { argument -> String? in
            switch argument {
            case "--continue", "-c":
                "--continue"
            case "--resume", "-r":
                "--resume"
            case "--from-claude":
                "--from-claude"
            case "--from-codex":
                "--from-codex"
            default:
                argument.hasPrefix("--resume=") ? "--resume" : nil
            }
        }
        if let first = sessionSelectors.first,
            let second = sessionSelectors.dropFirst().first
        {
            return "\(first) cannot be combined with \(second)."
        }
        if arguments.contains("--prewalk"), arguments.contains("--no-prewalk") {
            return "--prewalk cannot be combined with --no-prewalk."
        }
        if arguments.contains("--tools"), arguments.contains("--no-tools") {
            return "--tools cannot be combined with --no-tools."
        }
        return nil
    }
    static func resolve(
        userArguments: [String],
        sessionID: String?,
        continueWhenMissing: Bool
    ) -> OhMyPiLaunchPolicy {
        let hasExplicitSessionChoice = userArguments.contains { argument in
            argument == "--no-session" || argument == "--resume" || argument.hasPrefix("--resume=")
                || argument == "-r" || argument == "--continue" || argument == "-c"
                || argument == "--from-claude" || argument == "--from-codex"
        }
        guard !hasExplicitSessionChoice else {
            return OhMyPiLaunchPolicy(arguments: userArguments, expectedSessionID: nil)
        }
        if let sessionID, !sessionID.isEmpty {
            return OhMyPiLaunchPolicy(
                arguments: userArguments + ["--resume", sessionID], expectedSessionID: sessionID)
        }
        if continueWhenMissing {
            return OhMyPiLaunchPolicy(arguments: userArguments + ["--continue"], expectedSessionID: nil)
        }
        return OhMyPiLaunchPolicy(arguments: userArguments, expectedSessionID: nil)
    }
}
