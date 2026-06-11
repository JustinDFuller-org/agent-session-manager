import Foundation

enum PaneActivityState {
    case idle
    case working
    case stopped
    case waiting
}

func paneActivityState(
    processState: TerminalController.ProcessState?,
    isWorking: Bool,
    isStopped: Bool = false,
    sessionState: String?,
    hasNotification: Bool
) -> PaneActivityState {
    if hasNotification { return .waiting }
    guard case .running = processState else { return .idle }
    let isBusy = sessionState == "busy" || sessionState == "retry"
    if isWorking || isBusy { return .working }
    if isStopped { return .stopped }
    return .idle
}

func tabActivityState(_ paneStates: [PaneActivityState]) -> PaneActivityState {
    if paneStates.contains(.waiting) { return .waiting }
    if paneStates.contains(.working) { return .working }
    if paneStates.contains(.stopped) { return .stopped }
    return .idle
}
