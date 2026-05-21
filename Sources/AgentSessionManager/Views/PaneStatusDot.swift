import SwiftUI

func paneStatusDotColor(
    pr: PullRequest?,
    isMerged: Bool,
    processState: TerminalController.ProcessState?
) -> Color {
    if let pr { return pr.circleColor }
    if isMerged { return .purple }
    switch processState {
    case .running: return .green
    case .exited: return .gray.opacity(0.4)
    default: return .gray
    }
}
