import Foundation

enum PaneActivityState {
    case idle
    case working
    case waiting
}

func paneActivityState(
    processState: TerminalController.ProcessState?,
    isProducingOutput: Bool,
    sessionState: String?,
    hasNotification: Bool
) -> PaneActivityState {
    if hasNotification { return .waiting }
    guard case .running = processState else { return .idle }
    let isBusy = sessionState == "busy" || sessionState == "retry"
    if isProducingOutput || isBusy { return .working }
    return .idle
}

func tabActivityState(_ paneStates: [PaneActivityState]) -> PaneActivityState {
    if paneStates.contains(.waiting) { return .waiting }
    if paneStates.contains(.working) { return .working }
    return .idle
}
