import Foundation

struct OhMyPiLaunchPolicy: Equatable {
    let arguments: [String]
    let expectedSessionID: String?

    static func resolve(
        userArguments: [String],
        sessionID: String?,
        continueWhenMissing: Bool
    ) -> OhMyPiLaunchPolicy {
        let hasExplicitSessionChoice = userArguments.contains { argument in
            argument == "--no-session" || argument == "--resume" || argument.hasPrefix("--resume=")
                || argument == "-r" || argument == "--continue" || argument == "-c"
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
